// Simplified emulation of Cal.com's Retell AI Phone Service

const handleCreatePhoneCall = async ({ numberToCall, generalPrompt, dynamicVariables }) => {
  try {
    // Cal.com hits LegacyRetellAIService here
    console.log(`[Retell DEV] Outbound call requested to ${numberToCall}`);
    console.log(`[Retell DEV] Prompt: ${generalPrompt}`);
    console.log(`[Retell DEV] Vars:`, dynamicVariables);

    // Mock response simulating Retell SDK
    return {
      callId: `call_${Date.now()}_mock`,
      agentId: `agent_mock_123`
    };
  } catch (err) {
    console.error('Failed to trigger Retell Call', err);
    throw err;
  }
};

module.exports = { handleCreatePhoneCall };
