-- Standalone entry point for the Arturia KeyStep side-channel interceptor.

local keyStep = require("keystep")

return {
  id = "keystep_interceptor",
  name = "Arturia KeyStep Interceptor",
  start = keyStep.start,
  stop = keyStep.stop,
  connect = keyStep.connect,
  disconnect = keyStep.disconnect,
  checkConnection = keyStep.checkConnection,
  isConnected = keyStep.isConnected,
  setHud = keyStep.setHud,
  handleGuiAction = keyStep.handleGuiAction,
  getState = keyStep.getState,
  resetTiming = keyStep.resetTiming,
  handleMidiEvent = keyStep.handleMidiEvent,
  showMonitor = keyStep.showMonitor,
  hideMonitor = keyStep.hideMonitor,
  toggleMonitor = keyStep.toggleMonitor,
  getFullState = keyStep.getFullState,
  syncToHud = keyStep.syncToHud,
  analyzeSequenceAndInferKnobs = keyStep.analyzeSequenceAndInferKnobs,
}
