const express = require('express');
const router = express.Router();
const aiService = require('../services/aiService');
const { Member, MembershipType, LedgerScan, AttendanceSession, Payment, sequelize } = require('../models');
const { Op } = require('sequelize');
const dayjs = require('dayjs');
const Fuse = require('fuse.js');

const { scanRateLimiter, validateImagePayload } = require('../middleware/aiControl');

// POST /api/ai/scan-book
// Now uses req.gymId from resolveGymId middleware
router.post('/scan-book', scanRateLimiter, validateImagePayload, async (req, res) => {
  try {
    const imageData = req.body.imageBase64 || req.body.image;

    const entries = await aiService.extractGymRecords(imageData, {
      text: `Extract ALL entries from this gym attendance and payment logbook photo.
For each row extract every field you can see.
Return ONLY a valid JSON array. No markdown. No extra text. No explanation.
Each entry must have exactly these fields:
{
  "member_name": "string",
  "date": "string or null",
  "attended": true or false,
  "amount": number or null,
  "payment_status": "paid" or "due" or "pending" or "trial" or null,
  "payment_method": "cash" or "upi" or "bank" or "other" or null,
  "is_trial": true or false,
  "notes": "string or null"
}
Extract whatever is visible. Do not skip fields. Do not assume a fixed format.`
    });

    if (!Array.isArray(entries) || entries.length === 0) {
      return res.status(422).json({ 
        success: false, 
        error: 'PARSE_FAILED',
        message: 'Could not read the image. Please retake in better lighting.'
      });
    }

    const members = await Member.findAll({
      where: { gym_id: req.gymId },
      attributes: [
        'id', 'member_name', 'phone', 
        'status', 'join_date', 'membership_type_id'
      ]
    });

    const fuse = new Fuse(members.map(m => m.toJSON()), {
      keys: ['member_name'],
      threshold: 0.4,
      includeScore: true
    });

    const enrichedEntries = entries.map(entry => {
      const results = fuse.search(entry.member_name);
      const matches = results.slice(0, 3).map(r => ({
        id: r.item.id,
        name: r.item.member_name,
        phone: r.item.phone,
        status: r.item.status,
        join_date: r.item.join_date,
        membership_type_id: r.item.membership_type_id,
        confidence: Math.round((1 - r.score) * 100)
      }));

      const highConfidenceMatches = matches.filter(m => m.confidence >= 85);
      const requires_manual_selection = highConfidenceMatches.length > 1;

      return {
        ...entry,
        ai_read_name: entry.member_name,
        matches,
        requires_manual_selection
      };
    });

    const scan = await LedgerScan.create({
      gym_id: req.gymId,
      scanned_at: dayjs.utc().toDate(),
      raw_extracted_json: enrichedEntries,
      confirmed: false,
      total_entries: enrichedEntries.length
    });

    res.json({ success: true, scan_id: scan.id, entries: enrichedEntries });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// POST /api/ai/scan/:scan_id/confirm
router.post('/scan/:scan_id/confirm', async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const { entries } = req.body;

    const scan = await LedgerScan.findOne({
      where: { id: req.params.scan_id, gym_id: req.gymId } // Verify scan belongs to this gym
    });

    if (!scan) {
      await t.rollback();
      return res.status(404).json({
        success: false,
        message: 'Scan not found or unauthorized'
      });
    }

    if (scan.confirmed) {
      await t.rollback();
      return res.status(409).json({
        success: false,
        message: 'This scan has already been confirmed'
      });
    }

    let processed = 0;
    let skipped = 0;
    const skipped_reasons = [];

    for (const entry of entries) {
      if (entry.action === 'skip') {
        skipped++;
        skipped_reasons.push(`${entry.ai_read_name} — skipped by owner`);
        continue;
      }

      let member;

      if (entry.action === 'new_member') {
        const rawPhone = (entry.phone || '').replace(/\D/g, '');
        if (!rawPhone) {
          skipped++;
          skipped_reasons.push(`${entry.ai_read_name} — phone number required for new member`);
          continue;
        }
        const phone = rawPhone.startsWith('91') && rawPhone.length === 12
          ? `+${rawPhone}`
          : `+91${rawPhone.slice(-10)}`;

        let expiry_date = null;
        let membershipTypeId = entry.membership_type_id || null;

        if (entry.is_trial) {
          expiry_date = dayjs.utc().add(30, 'day').toDate();
          membershipTypeId = null;
        } else if (membershipTypeId) {
          const plan = await MembershipType.findOne({ where: { id: membershipTypeId, gym_id: req.gymId }, transaction: t });
          if (plan) expiry_date = dayjs.utc().add(plan.duration_months, 'month').toDate();
          else membershipTypeId = null;
        }

        member = await Member.create({
          gym_id: req.gymId,
          member_name: entry.ai_read_name,
          phone,
          status: entry.is_trial ? 'trial' : 'active',
          is_trial: entry.is_trial || false,
          membership_type_id: membershipTypeId,
          join_date: dayjs.utc().format('YYYY-MM-DD'),
          expiry_date,
          payment_collected: false,
          total_visits: 0,
          lifetime_value: 0,
        }, { transaction: t });
      } else {
        if (!entry.selected_member_id) {
          skipped++;
          skipped_reasons.push(`${entry.ai_read_name} — no member linked`);
          continue;
        }
        member = await Member.findOne({
          where: { id: entry.selected_member_id, gym_id: req.gymId },
          transaction: t
        });
        if (!member) {
          skipped++;
          skipped_reasons.push(`${entry.ai_read_name} — member not found`);
          continue;
        }
      }

      if (entry.attended) {
        const existingAttendance = await AttendanceSession.findOne({
          where: {
            member_id: member.id,
            date: entry.date || dayjs.utc().format('YYYY-MM-DD')
          },
          transaction: t
        });

        if (!existingAttendance) {
          await AttendanceSession.create({
            gym_id: req.gymId,
            member_id: member.id,
            check_in_time: dayjs.utc().toDate(),
            date: entry.date || dayjs.utc().format('YYYY-MM-DD')
          }, { transaction: t });

          await member.increment('total_visits', { transaction: t });
        } else {
          skipped_reasons.push(`${member.member_name} — attendance already recorded today`);
        }
      }

      if (entry.amount && entry.amount > 0) {
        const existingPayment = await Payment.findOne({
          where: {
            member_id: member.id,
            payment_date: { [Op.gte]: dayjs.utc().startOf('day').toDate() }
          },
          transaction: t
        });

        if (!existingPayment) {
          const paymentStatus = entry.payment_status === 'due' || entry.payment_status === 'pending' ? 'pending' : 'paid';

          await Payment.create({
            gym_id: req.gymId,
            member_id: member.id,
            amount: entry.amount,
            status: paymentStatus,
            payment_date: dayjs.utc().toDate(),
            method: entry.payment_method || 'ledger_scan'
          }, { transaction: t });

          if (paymentStatus === 'paid') {
            await member.update({
              payment_collected: true,
              last_payment_date: dayjs.utc().toDate(),
              lifetime_value: member.lifetime_value + entry.amount
            }, { transaction: t });
          }
        } else {
          skipped_reasons.push(`${member.member_name} — payment already recorded today`);
        }
      }

      if (entry.is_trial) {
        await member.update({ is_trial: true, status: 'trial' }, { transaction: t });
      }

      processed++;
    }

    await scan.update({
      confirmed: true,
      confirmed_at: dayjs.utc().toDate(),
      processed_entries: processed,
      skipped_entries: skipped
    }, { transaction: t });

    await t.commit();
    res.json({ success: true, processed, skipped, skipped_reasons });

  } catch (err) {
    if (t) await t.rollback();
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/ai/scans
// Uses req.gymId from resolveGymId middleware
router.get('/scans', async (req, res) => {
  try {
    const scans = await LedgerScan.findAll({
      where: { gym_id: req.gymId },
      attributes: ['id', 'scanned_at', 'confirmed', 'confirmed_at', 'total_entries', 'processed_entries', 'skipped_entries'],
      order: [['scanned_at', 'DESC']],
      limit: 50
    });
    res.json({ success: true, data: scans });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/ai/test
router.get('/test', async (req, res) => {
  try {
    const text = await aiService.ping();
    res.status(200).json({ success: true, status: "Sovereign AI is ALIVE", aiContent: text });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
