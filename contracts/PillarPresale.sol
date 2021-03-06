pragma solidity ^0.4.11;

import './zeppelin/SafeMath.sol';
import './zeppelin/ownership/Ownable.sol';
import './zeppelin/lifecycle/Pausable.sol';

contract PillarPresale is Pausable {
  using SafeMath for uint;
  uint constant totalPresaleSupply = 44000000;
  uint constant presaleSupply = 40000000;
  uint constant discountSupply = 4000000;

  address pillarTokenFactory;
  uint totalUsedTokens;
  mapping(address => uint) balances;
  //Sale Period
  address[] purchasers;
  uint public salePeriod;

  uint startBlock;
  uint endBlock;

  //price will be in finney
  //uint constant PRESALE_PRICE = 1 finney;
  uint constant PRESALE_PRICE = 0.00042 ether;

  function PillarPresale(address _pillarTokenFactory,uint _startBlock,uint _endBlock) {
    if(_pillarTokenFactory == address(0)) throw;
    if(_endBlock <= _startBlock) throw;

    //presale is open for
    salePeriod = now.add(48 hours);
    startBlock = _startBlock;
    endBlock = _endBlock;
    pillarTokenFactory = _pillarTokenFactory;
    totalUsedTokens = 0;
  }

  function () external whenNotPaused payable {
    if(now > salePeriod) throw;
    if(block.number < startBlock) throw;
    if(block.number > endBlock) throw;
    if(totalUsedTokens >= totalPresaleSupply) throw;
    if(msg.value < PRESALE_PRICE) throw;
    if(msg.value > 500 ether) throw;

    uint numTokens = msg.value.div(PRESALE_PRICE);
    if(numTokens < 1) throw;
    //1 token discount for every 10 tokens sold
    uint discountTokens = numTokens.div(10);
    numTokens = numTokens.add(discountTokens);

    totalUsedTokens = totalUsedTokens.add(numTokens);
    if (totalUsedTokens > totalPresaleSupply) throw;

    //transfer money to PillarTokenFactory MultisigWallet
    pillarTokenFactory.transfer(msg.value);

    purchasers.push(msg.sender);
    balances[msg.sender] = balances[msg.sender].add(numTokens);
  }

  function getTotalPresaleSupply() external constant returns (uint256) {
    return totalPresaleSupply;
  }

  //@notice Function reports the number of tokens available for sale
  function numberOfTokensLeft() constant returns (uint256) {
    uint tokensAvailableForSale = totalPresaleSupply.sub(totalUsedTokens);
    return tokensAvailableForSale;
  }

  function finalize() external whenNotPaused onlyOwner {
    if(block.number < endBlock && totalUsedTokens < presaleSupply) throw;

    pillarTokenFactory.transfer(this.balance);
    paused = true;
  }

  function balanceOf(address owner) constant returns (uint) {
    return balances[owner];
  }

  function getPurchasers() onlyOwner whenPaused external returns (address[]) {
    return purchasers;
  }

  function numOfPurchasers() onlyOwner external constant returns (uint) {
    return purchasers.length;
  }
}
