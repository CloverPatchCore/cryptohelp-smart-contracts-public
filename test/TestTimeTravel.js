/* const { BN } = web3.utils;
require("chai").use(require("chai-bn")(BN)).should();

const {
  timeTravelTo,
  timeTravelToBlock
} = require("./helper");


contract('NONE', () => {
  describe('Test time travel', async () => {
    it("should be time traveled to the timestamp", async () => {
      // lock current time
      await timeTravelTo(0);
      const originalBlock = await web3.eth.getBlock('latest');

      // go to block after 100 seconds
      await timeTravelTo(100);
      const newBlock = await web3.eth.getBlock('latest');

      assert.equal(originalBlock.timestamp+100, newBlock.timestamp, "Time not added the time");
    });

    it("should advance the blockchain forward a block", async () =>{
      let originalBlock = await web3.eth.getBlock('latest')
      const originalBlockHash = originalBlock.hash;
      let newBlockHash = await web3.eth.getBlock('latest').hash;

      newBlockHash = await timeTravelToBlock(originalBlockHash+1);

      assert.notEqual(originalBlockHash, newBlockHash, "next block hash was not mined");
    });
  });
}) */