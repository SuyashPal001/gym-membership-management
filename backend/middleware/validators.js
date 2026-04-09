const { body, validationResult } = require('express-validator');

// ─── Middleware to handle validation errors ───────────────────────────────────
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (errors.isEmpty()) {
    return next();
  }
  return res.status(400).json({
    success: false,
    errors: errors.array().map(err => ({ field: err.path, message: err.msg }))
  });
};

// ─── Member Validation Rules ──────────────────────────────────────────────────
const memberValidationRules = [
  body('gym_id').isUUID().withMessage('Valid Gym ID is required'),
  body('member_name')
    .trim()
    .notEmpty().withMessage('Name is required')
    .isLength({ min: 2 }).withMessage('Name must be at least 2 characters')
    .escape(),
  body('phone')
    .trim()
    .notEmpty().withMessage('Phone is required')
    .matches(/^[0-9+\- ]+$/).withMessage('Invalid phone format'),
  body('email')
    .optional({ checkFalsy: true })
    .trim()
    .isEmail().withMessage('Invalid email format')
    .normalizeEmail(),
  body('membership_type_id').optional({ nullable: true }).isUUID().withMessage('Invalid membership type ID'),
  body('is_trial').optional().isBoolean().withMessage('is_trial must be a boolean'),
  body('payment_collected').optional().isBoolean().withMessage('payment_collected must be a boolean'),
];

module.exports = {
  validate,
  memberValidationRules,
};
