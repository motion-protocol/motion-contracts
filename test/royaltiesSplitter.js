/**
 * Copyright (c) 2018-present, Leap DAO (leapdao.org)
 *
 * This source code is licensed under the Mozilla Public License, version 2,
 * found in the LICENSE file in the root directory of this source tree.
 */

const RoyaltiesSplitter = artifacts.require('RoyaltiesSplitter');
const ERC1948 = artifacts.require('./mocks/ERC1948');
require('./helpers/setup');

function replaceAll(str, find, replace) {
    return str.replace(new RegExp(find, 'g'), replace.replace('0x', '').toLowerCase());
}

contract('RoyaltiesSplitter', (accounts) => {

  const rightsHolder = accounts[0];
  // preimage: 0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000
  const EMPTY_HASH = '0x569e75fc77c1a856f6daaf9e69d8a9566ca34aa47f9133711ce065a571af0cfd';
  const ADDR_1 = '0x1231111111111111111111111111111111111123';
  const ADDR_2 = '0x2341111111111111111111111111111111111234';
  const ADDR_3 = '0x3451111111111111111111111111111111111345';
  const ADDR_4 = '0x4561111111111111111111111111111111111456';
  const AMOUNT = 124000000;
  let originalByteCode;
  let rightsRegistry;
  const rightsId = 123;

  beforeEach(async () => {
    rightsRegistry = await ERC1948.new();
    originalByteCode = RoyaltiesSplitter._json.bytecode; // eslint-disable-line no-underscore-dangle
  });

  // eslint-disable-next-line no-undef
  afterEach(() => {
    RoyaltiesSplitter._json.bytecode = originalByteCode; // eslint-disable-line no-underscore-dangle
  });

  it('can sort 1', async () => {
    const splitter = await RoyaltiesSplitter.new();
    const hash1 = await splitter.sortAndHash([ADDR_1], [AMOUNT]);
    // preimage: 0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000011231111111111111111111111111111111111123000000000000000007641700
    const hash = '0x3274b7ee060fa41bf0a20baf8a4edc7330dc073acaabe6570e0361187b407a29';
    assert.equal(hash1, hash);
  });

  it('can sort 2', async () => {
    const splitter = await RoyaltiesSplitter.new();
    const hash1 = await splitter.sortAndHash([ADDR_2, ADDR_1], [AMOUNT, AMOUNT]);
    const hash2 = await splitter.sortAndHash([ADDR_1, ADDR_2], [AMOUNT, AMOUNT]);
    // preimage: 0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000212311111111111111111111111111111111111230000000000000000076417002341111111111111111111111111111111111234000000000000000007641700
    const hash = '0x5995411c9c4bfedc9b7f8de8303ab22a36a087610971027a9cf30acd77ff1b18';
    assert.equal(hash1, hash);
    assert.equal(hash2, hash);
  });

  it('can sort 3', async () => {
    const splitter = await RoyaltiesSplitter.new();
    const hash1 = await splitter.sortAndHash([ADDR_3, ADDR_2, ADDR_1], [AMOUNT, AMOUNT, AMOUNT]);
    const hash2 = await splitter.sortAndHash([ADDR_1, ADDR_2, ADDR_3], [AMOUNT, AMOUNT, AMOUNT]);
    const hash = '0xc2627ae51f504959e96bb1dc6f90237e1f38693e24a820e48531d5eb9cbc1d6d';
    assert.equal(hash1, hash);
    assert.equal(hash2, hash);
  });

  it('can sort 4', async () => {
    const splitter = await RoyaltiesSplitter.new();
    const hash1 = await splitter.sortAndHash(
      [ADDR_3, ADDR_4, ADDR_2, ADDR_1], [AMOUNT, AMOUNT, AMOUNT, AMOUNT]);
    const hash2 = await splitter.sortAndHash(
      [ADDR_1, ADDR_4, ADDR_2, ADDR_3], [AMOUNT, AMOUNT, AMOUNT, AMOUNT]);
    const hash = '0x6d9b0dd883e0820f1915c6998ee2b25fcbcb5534bb3ffe6b14b59da84ff35d34';
    assert.equal(hash1, hash);
    assert.equal(hash2, hash);
  });

  it('can add owner', async () => {

    // deploy vote contract
    let tmp = RoyaltiesSplitter._json.bytecode; // eslint-disable-line no-underscore-dangle
    // replace token address placeholder to real token address
    tmp = replaceAll(tmp, ADDR_1.replace('0x', ''), rightsRegistry.address);
    RoyaltiesSplitter._json.bytecode = tmp; // eslint-disable-line no-underscore-dangle
    const splitter = await RoyaltiesSplitter.new();

    await rightsRegistry.mint(rightsHolder, rightsId);
    await rightsRegistry.writeData(rightsId, EMPTY_HASH, {from: rightsHolder});
    await rightsRegistry.approve(splitter.address, rightsId, {from: rightsHolder});

    // sending transaction
    await splitter.addOwner(
      rightsId,
      [],
      ADDR_1,
      AMOUNT
    ).should.be.fulfilled;

    const hash = await splitter.sortAndHash([ADDR_1], [AMOUNT]);
    const newHash = await rightsRegistry.readData(rightsId);
    assert.equal(hash, newHash);
  });

});