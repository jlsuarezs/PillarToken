pragma solidity ^0.4.8;

import './TeamAllocation.sol';
import './ERC20Interface.sol';
import './SafeMath.sol';
import './MigrationAgent.sol';

contract PillarToken is ERC20Interface {

    using SafeMath for uint;
    string public constant name = "PILLAR";
    string public constant symbol = "PLR";
    //uint8 costs more gas than uint246/uint so changed the data type
    uint public constant decimals = 18;

    address public migrationAgent;
    address public migrationMaster;
    uint public totalMigrated;

    TeamAllocation tAll;
    TeamAllocation public lockedAllocation;

    uint  public constant totalNumberOfTokens = 10000000;

    /* Check ETH/USD rate on the day of the ICO */
    /* 1 ETH = 88 USD ; 1/88 of USD expressed in WEI */
    // Need to revisit this value at later point
    uint public constant tokenPrice  = 11363636363637 wei;

    //address corresponding to the pillar token factory where the fund raised will be held.
    address public pillarTokenFactory;

    // Minimum token creation
    uint public constant minTokensForSale = 2000000;
    //tokens reserved for team.
    uint public constant tokensReservedForTeam = 300000;
    //tokens reserved for 20|30 projects
    uint public constant tokensReservedFor2030Projects = 1000000;
    //tokens reserved for future sale
    uint public constant tokensForFutureSale = 1700000;
    //total tokens available for sale
    uint public constant tokensAvailableForSale = (totalNumberOfTokens - (tokensReservedForTeam + tokensReservedFor2030Projects + tokensForFutureSale));
    //Sale Period
    uint public salePeriod;

    uint fundingStartBlock;
    uint fundingStopBlock;

    // flags whether ICO is afoot.
    bool fundingMode = true;

    //total used tokens
    uint totalUsedTokens;

    mapping (address => uint256) balances;

    //event Approval(address indexed _owner, address indexed _spender,uint _value);
    //event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Refund(address indexed _from,uint256 _value);
    event Migrate(address indexed _from, address indexed _to, uint256 _value);

    function PillarToken(address _pillarTokenFactory, uint256 _fundingStartBlock, uint256 _fundingStopBlock, address _migrationMaster) {

      //sale peioriod
      salePeriod = now + 60 hours;

      pillarTokenFactory = _pillarTokenFactory;
      migrationMaster = _migrationMaster;
      fundingStartBlock = _fundingStartBlock;
      fundingStopBlock = _fundingStopBlock;
      totalUsedTokens = 0;
    }

    /*
    * Function used to validate conditions in case the contract is called with incorrect data
    */
    function() payable external {
      if(!fundingMode) throw;
      if(now > salePeriod) throw;
      if(block.number < fundingStartBlock) throw;
      if(block.number > fundingStopBlock) throw;
      if(totalUsedTokens >= tokensAvailableForSale) throw;

      if (msg.value == 0) throw;

      //total tokens purchased is received gas/cost of 1 token
      var numTokens = msg.value / tokenPrice;
      totalUsedTokens += numTokens;
      if (totalUsedTokens > tokensAvailableForSale) throw;

      // Assign new tokens to sender
      balances[msg.sender] += numTokens;
      // log token creation event
      Transfer(0, msg.sender, numTokens);
    }

    function checkSalePeriod() external constant returns (uint) {
      return salePeriod;
    }

    function totalSupply() constant returns (uint totalSupply) {
      //return totalTokens;
      totalSupply = tokensAvailableForSale;
    }

    function balanceOf(address owner) constant returns (uint balance) {
      //return balances[owner];
      balance = balances[owner];
    }

    // ICO
    function fundingActive() constant external returns (bool){
      if(!fundingMode) return false;

      //Shouldn't this be total tokensAvailableForSale? Earlier the check was against minTokensForSale
      if(block.number < fundingStartBlock || block.number > fundingStopBlock || totalUsedTokens > tokensAvailableForSale){
        return false;
      }
      return true;
    }

    function numberOfTokensLeft() constant external returns (uint256) {
      if (!fundingMode) return 0;
      if (block.number > fundingStopBlock) {
        return 0;
      }
      return (tokensAvailableForSale - totalUsedTokens);
    }

    function isFinalized() constant external returns (bool){
      return !fundingMode;
    }

    function finalize() external {
      if (!fundingMode) throw;
      if ((block.number <= fundingStopBlock ||
        totalUsedTokens < minTokensForSale) &&
        totalUsedTokens < tokensAvailableForSale) throw;

        // switch funding mode off
        fundingMode = false;

        if (!pillarTokenFactory.send(this.balance)) throw;

        /*uint256 percentOfTotal = */
        // Shouldn't this reflect all of the remaining tokens and not just the 300,000?
        totalUsedTokens += tokensReservedForTeam;
        balances[lockedAllocation] += tokensReservedForTeam;
        Transfer(0, lockedAllocation, tokensReservedForTeam);
    }

    function refund() external {

      if(!fundingMode) throw;
      if(block.number <= fundingStopBlock) throw;
      if(totalUsedTokens >= minTokensForSale) throw;

      var ttaValue= balances[msg.sender];
      if(ttaValue == 0) throw;

      balances[msg.sender] = 0;

      totalUsedTokens -= ttaValue;

      var ethValue = ttaValue / tokenPrice;
      if(!msg.sender.send(ethValue)) throw;
      Refund(msg.sender, ethValue);
    }

    function transfer(address _to, uint256 _value) returns (bool) {
        // Abort if not in Operational state.
        if (fundingMode) throw;

        var senderBalance = balances[msg.sender];
        if (senderBalance >= _value && _value > 0) {
            senderBalance -= _value;
            balances[msg.sender] = senderBalance;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        }
        return false;
    }

    // token migration
    function migrate(uint256 _value) external {
      if (fundingMode) throw;
      if (migrationAgent == 0) throw;

      if (_value == 0) throw;
      if (_value > balances[msg.sender]) throw;

      balances[msg.sender] -= _value;
      totalUsedTokens -= _value;
      totalMigrated += _value;
      MigrationAgent(migrationAgent).migrateFrom(msg.sender, _value);

      Migrate(msg.sender, migrationAgent, _value);
    }

    function setMigrationAgent(address _agent) external{
      if(fundingMode) throw;
      if(migrationAgent != migrationAgent) throw;
      if(msg.sender != migrationMaster) throw;
      migrationAgent = _agent;
    }

    function setMigrationMaster(address _master) external {
      if(msg.sender != migrationMaster) throw;
      migrationMaster = _master;
    }

    /* As per the discussion with David in todays ICO call, there is a requirement for two new methods
    * that will allow David, Michael etc to transfer token to different ethereum wallets
    * for donations received through fiat or non crypto currencies
    */
}

/* Check Token.sol here https://github.com/maraoz/golem-crowdfunding/tree/master/contracts

Token Name: Pillar
Abbreviation: PLR
No. of decimal places per token: 18
Total number of tokens issued: 10,000,000 tokens
Tokens on offer for ICO: 7,000,000



Nominal price per Token: 1 USD (to be priced in ether ahead of the event)
Period Team token is marked locked: 9 months
Total Token sale period: 60 hours or until target is reached.
Minimum Token to sell within offer period or return all sent: 2,000,000

Team tokens can either be transferred automatically or a transfer() method would be invoked manually after 12 months.
All Tokens will be tradable as soon as we can get them listed on an exchange - estimate is 2 months from ICO.

Sale Structure
Token sale is terminated:
7,000,000 tokens are sold
60 hours have elapsed from ICO start date

Minimum sale
If tokens sold after 60 hours < 2,000,000,  then:
full refund to all donators


Key
Token sale & ICO have been used interchangeably.


*/