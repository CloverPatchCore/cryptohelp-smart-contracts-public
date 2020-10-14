const MandateBook = artifacts.require('./MandateBook');

contract('MandateBook', (accounts) => {

  const OWNER = accounts[0];

  let mandateBook;

  before('setup', async () => {
    mandateBook = await MandateBook.new({from: OWNER})
  });

  afterEach('revert', async () => {
    //
  });

  describe('status', async () => {
    it('should doing smth', async () => {
      //
    });
  });
})