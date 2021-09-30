const BN = require("bn.js");

const timeMachine = require('ganache-time-traveler');

module.exports = {
  testReject,
  timeTravelTo,
  timeTravelToDate,
  timeTravelToBlock,
  takeSnapshot,
  revertToSnapshot,
  expandTo18Decimals
}

const REVERT_PREFIX = 'Returned error: VM Exception while processing transaction: revert ';
const REVERT_WITHOUT_AN_ERROR = REVERT_PREFIX.slice(0, REVERT_PREFIX.length - 1);

function testReject(func, revertMessage=null) {
  let error = null;
  it('should rejects', async () => {
    try {
      await func();
    } catch (err) {
      error = err;
      return;
    }
    throw new Error('not rejects');
  });
  let isRevert = false;
  it('revert instructions', function () {
    if (!error) this.skip();
    assert(
      error.message.startsWith(REVERT_WITHOUT_AN_ERROR),
      `error "${error.message}" is not revert instruction error`,
    );
    isRevert = true;
  });
  if (revertMessage === undefined) {
    it('without any message', function () {
      if (!isRevert || !error) this.skip();
      else assert(error.message === REVERT_WITHOUT_AN_ERROR);
    });
  } else {
    it(`with message "${revertMessage}"`, function () {
      if (!isRevert || !error) this.skip();
      else assert(error.message.startsWith(REVERT_PREFIX + revertMessage), `found: ${error.message}`);
    });
  }
}

/**
 * @function Move chain to current block time
 * @param time number(timestamp)
 * @returns {Promise<*>}
 */
async function timeTravelTo(time=0) {
  return timeMachine.advanceTimeAndBlock(time);
}

/**
 *
 * @param time
 * @returns {Promise<*>}
 */
async function timeTravelToDate(time) {
  return timeMachine.advanceTime(time);
}

/**
 *
 * @param block
 * @returns {Promise<*>}
 */
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

/**
 *
 * @param n number
 * @returns {BN}
 */
function expandTo18Decimals(n) {
  return new BN(n).mul(new BN(10).pow(new BN(18)));
}

