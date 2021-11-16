// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IDEXRouter.sol";

/**
 * @title BloodPresale part of TulipDao
 * https://thetulipdao.com
 */
contract BloomPresale is AccessControlEnumerable, ReentrancyGuard {
    using SafeMath for uint256;
    mapping(address => bool) private _whitelist;        // addresses allowed to buy and claim
    mapping(address => uint256) private _amountBought;  // tracks how much tokens are bought for each address
    mapping(address => uint256) private _amountClaimed; // tracks how much tokens are claimed for each address
    address private _token;                             // ERC20 token
    uint256 private _price;                             // FTM per 600
    uint256 private _minBuy;                            // min FTM to spend
    uint256 private _maxBuy;                            // max FTM to spend
    uint256 private _totalBought;                       // total tokens bought
    uint256 private _totalPresale;                      // total amount for presale. totalBought should be less than this
    uint256 private _launchTime;                        // Time launch
    address private _router;                            // Address of router (spirit)
    bool private _presaleOn;
    bool private _claimOn;
    bool private _launched;
    bool private _publicBuy;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");       // df8b4c520ffe197c5343c6f5aec59570151ef9a492f2c624fd45ddde6135ec42

    receive() external payable {}

    fallback() external payable {}

    constructor() {
        __BloomPresale_init_unchained();
    }

    function __BloomPresale_init_unchained() internal {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(ADMIN_ROLE, _msgSender());
        _price = 1 ether; // 1000000000000000000 wei to get 600000000000000000000 wei of token
        _price = _price / 600; // 1666666666666666 wei (0.001666666666666666 ether)
        _minBuy = 50 ether;
        _maxBuy = 250 ether;
        _totalPresale = 27272727 ether; // total token available for presale
        _router = 0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52; // spirit router
    }

    function buy() payable public nonReentrant {
        require(_presaleOn, "Presale not on");
        if(!_publicBuy) {
            require(_whitelist[_msgSender()], "Not whitelisted");
        }
        require(msg.value >= _minBuy, "Min buy not met");
        require(msg.value == _minBuy || msg.value == 100 ether || msg.value == 150 ether || msg.value == 200 ether || msg.value == _maxBuy, "Incorrect amount");
        // amount of tokens user bought
        uint256 amount = msg.value / _price; // max should be 300000 token
        require((_amountBought[_msgSender()] * _price) + msg.value <= _maxBuy, "Exceeds max buy limit");
        require(_totalBought + amount <= _totalPresale, "Exceeds supply");
        _amountBought[_msgSender()] += amount;
        _totalBought += amount;
    }

    function claim() public nonReentrant {
        require(_claimOn, "Claim not on");
        require(_amountClaimed[_msgSender()] < _amountBought[_msgSender()], "Nothing to claim");
        require(amount >= IERC20(_token).balanceOf(address(this)), "Not enough balance in contract");

        uint256 amount = _amountBought[_msgSender()];
        if(IERC20(_token).balanceOf(address(this)) < amount) {
            amount = IERC20(_token).balanceOf(address(this));
        }
        IERC20(_token).transferFrom(address(this), _msgSender(), amount);
        _amountClaimed[_msgSender()] += amount;
    }

    function getAmountBought(address account_) public view returns(uint256) {
        return _amountBought[account_];
    }

    function getAmountClaimed(address account_) public view returns(uint256) {
        return _amountClaimed[account_];
    }

    function whitelistAddresses(address[] memory accounts_) public onlyRole(ADMIN_ROLE) {
        for(uint256 i = 0; i < accounts_.length; i++) {
            _whitelist[accounts_[i]] = true;
        }
    }

    function removeWhitelistAddress(address account_) public onlyRole(ADMIN_ROLE) {
        _whitelist[account_] = false;
    }

    function getWhitelistAddress(address account_) public view returns(bool) {
        return _whitelist[account_];
    }

    function setToken(address token_) public onlyRole(ADMIN_ROLE) {
        _token = token_;
    }

    function getToken() public view returns(address) {
        return _token;
    }

    function approveToken(address token_) public onlyRole(ADMIN_ROLE) {
        IERC20(token_).approve(address(this), IERC20(token_).totalSupply());
    }

    function setPrice(uint256 price_) public onlyRole(ADMIN_ROLE) {
        _price = price_;
    }

    function getPrice() public view returns(uint256) {
        return _price;
    }

    function setMinBuy(uint256 amount_) public onlyRole(ADMIN_ROLE) {
        _minBuy = amount_;
    }

    function getMinBuy() public view returns(uint256) {
        return _minBuy;
    }

    function setMaxBuy(uint256 amount_) public onlyRole(ADMIN_ROLE) {
        _maxBuy = amount_;
    }

    function getMaxBuy() public view returns(uint256) {
        return _maxBuy;
    }

    function getTotalBought() public view returns(uint256) {
        return _totalBought;
    }

    function setTotalPresale(uint256 amount) public onlyRole(ADMIN_ROLE) {
        _totalPresale = amount;
    }

    function getTotalPresale() public view returns(uint256) {
        return _totalPresale;
    }

    function launch() public onlyRole(ADMIN_ROLE) {
        require(!_launched, "Launched");
        _launched = true;
        _launchTime = block.timestamp;
    }

    function getLaunched() public view returns(bool) {
        return _launched;
    }

    function getLaunchTime() public view returns(uint256) {
        return _launchTime;
    }

    function setPresaleOn(bool on_) public onlyRole(ADMIN_ROLE) {
        _presaleOn = on_;
    }

    function getPresaleOn() public view returns(bool) {
        return _presaleOn;
    }

    function setClaimOn(bool on_) public onlyRole(ADMIN_ROLE) {
        _claimOn = on_;
    }

    function getClaimOn() public view returns(bool) {
        return _claimOn;
    }

    function setPublicBuy(bool on_) public onlyRole(ADMIN_ROLE) {
        _publicBuy = on_;
    }

    function getPublicBuy() public view returns(bool) {
        return _publicBuy;
    }

    /**
     * @dev add specified amount to liquidity
     * amountToken should be 31818182 ether
     * amountFTM should be 60000 ether
     */
    function addLiquidity(uint256 amountToken, uint256 amountFTM) public onlyRole(ADMIN_ROLE) {
        // add to liquidity
        if(amountFTM > address(this).balance) {
            amountFTM = address(this).balance;
        }
        IDEXRouter(_router).addLiquidityETH(_token, amountToken, amountToken, amountFTM, address(this), block.timestamp);
    }

    /**
     * @dev withdraw FTM
     */
    function withdraw() public onlyRole(ADMIN_ROLE) {
        require(block.timestamp >= _launchTime + 7 days, "Cannot be called yet");
        (bool sent,) = payable(_msgSender()).call{value: address(this).balance}("");
        require(sent, "Failed to send balance");
    }

    /**
     * @dev withdraw ERC20 tokens
     */
    function withdrawERC20(address token_, uint256 amount_) public onlyRole(ADMIN_ROLE) {
        require(block.timestamp >= _launchTime + 7 days, "Cannot be called yet");
        IERC20(token_).transferFrom(address(this), _msgSender(), amount_);
    }
}
