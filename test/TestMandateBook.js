const MandateBook = artifacts.require('./MandateBook');

contract('MandateBook', (accounts) => {

  const OWNER = accounts[0];
  const INVESTOR1 = accounts[1];
  const INVESTOR2 = accounts[2];
  const MANAGER1 = accounts[3];
  const MANAGER2 = accounts[4];
  const OUTSIDER = accounts[5];

  let mandateBook;

  before('setup', async () => {
    mandateBook = await MandateBook.deployed();
  });

  afterEach('revert', async () => {
    //
  });

  describe('Mandate LifeCycle Steps', async () => {
    it('Investor should be able to create a Mandate', async () => {
      //
    });
    it('Investor should be able to populate a Mandate');
    it('Investor should be able to submit a Mandate to a Manager');
    it('Manager should be able to accept the Mandate appointed by the Investor');
    it('Manager should be able to decline the Mandate appointed by the Investor');
    it('Investor should be able to deposit ethers to the Mandate before it\'s started');
    it('Manager should be able to deposit ethers as coollateral to the Mandate before it\'s started');
    it('Manager should be able to start the Mandate that they accepted before');
    it('Manager should be able to start the Mandate submitted to them by Investor');
    it('Manager should be able to close in profit Mandate');
    it('Manager should be able to close through the stoploss');
    it('Investor should be able to close through the stoploss');
    it('Manager should be able to settle the deal distributing the earnings');
    it('Investor should be able to settle the deal distributing the earnings');

  });
  describe('Access Violations Checks', async () => {});
})