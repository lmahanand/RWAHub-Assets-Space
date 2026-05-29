pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

  mapping(address => mapping(address => uint256)) private allowances;
  address[] private holders;
  
  // holderIndex stores index + 1
  // if value is 0, address is not in holder list
  mapping(address => uint256) private holderIndex;
  mapping(address => uint256) private dividends;

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
  
  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    _transfer(msg.sender, to, value);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    allowances[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    allowances[from][msg.sender] = allowances[from][msg.sender].sub(value);
    _transfer(from, to, value);
    emit Approval(from, msg.sender, allowances[from][msg.sender]);
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "No ETH sent");

    // user gets same amount of tokens as ETH deposited
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);

    // total supply also increases by same amount
    totalSupply = totalSupply.add(msg.value);
    _addHolder(msg.sender);
    emit Transfer(address(0), msg.sender, msg.value);
  }

  function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];

    require(amount > 0, "No balance");

    // burn all tokens of caller
    balanceOf[msg.sender] = 0;

    // reduce total supply
    totalSupply = totalSupply.sub(amount);
    _removeHolder(msg.sender);

    // send ETH back
    dest.transfer(amount);
    emit Transfer(msg.sender, address(0), amount);
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index == 0 || index > holders.length) {
      return address(0);
    }
    return holders[index - 1];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "No ETH sent");
    require(totalSupply > 0, "No supply");

    for (uint256 i = 0; i < holders.length; i++) {
      address holder = holders[i];

      // dividend share is based on current token balance
      uint256 amount = msg.value.mul(balanceOf[holder]).div(totalSupply);
      dividends[holder] = dividends[holder].add(amount);
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return dividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = dividends[msg.sender];

    require(amount > 0, "No dividend");

    // reset before transfer
    dividends[msg.sender] = 0;
    dest.transfer(amount);
  }

  function _transfer(address from, address to, uint256 value) internal {
    require(to != address(0), "Invalid address");

    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);

    // only update holder list when some token is actually moved
    if (value > 0) {
      _removeHolder(from);
      _addHolder(to);
    }

    emit Transfer(from, to, value);
  }

  function _addHolder(address holder) internal {
    if (balanceOf[holder] > 0 && holderIndex[holder] == 0) {
      holders.push(holder);
      holderIndex[holder] = holders.length;
    }
  }

  function _removeHolder(address holder) internal {
    if (balanceOf[holder] == 0 && holderIndex[holder] != 0) {
      uint256 holderArrayIndex = holderIndex[holder] - 1;
      uint256 lastArrayIndex = holders.length - 1;

      if (holderArrayIndex != lastArrayIndex) {
        address lastHolder = holders[lastArrayIndex];

        holders[holderArrayIndex] = lastHolder;
        holderIndex[lastHolder] = holderArrayIndex + 1;
      }

      holders.pop();
      holderIndex[holder] = 0;
    }
  }
}