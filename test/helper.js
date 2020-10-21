const timeMachine = require('ganache-time-traveler');

module.exports = {
  timeTravelTo,
  timeTravelToDate,
  timeTravelToBlock,
  takeSnapshot,
  revertToSnapshot
}

/**
 * @function Move chain to current block time
 * @param time number(timestamp)
 * @returns {Promise<*>}
 */
async function timeTravelTo(time=0) {
  return timeMachine.advanceTimeAndBlock(time);
}

async function timeTravelToDate(time) {
  return timeMachine.advanceTime(time);
}

async function timeTravelToBlock(block) {
  return timeMachine.advanceBlock(block);
}

/**
 * @function Create EVM snapshot
 * @returns {Promise<*>}
 */
async function takeSnapshot() {
  let snapshot = await timeMachine.takeSnapshot();
  return snapshot['result'];
}

/**
 * @function Revert to snapshot id
 * @param id of snapshot
 * @returns {Promise<*>}
 */
async function revertToSnapshot(id) {
  return timeMachine.revertToSnapshot(id);
}

