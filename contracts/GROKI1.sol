//SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

pragma solidity ^0.8.18;

contract GROKI1 is ERC20, Ownable {
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    mapping(string name => uint256) sellFees;
    mapping(string name => uint256) buyFees;
    mapping(string name => uint256) feeAmounts;
    mapping(string name => address account) feeWallets;

    string[] private feeNames;

    uint256 public totalBuyFee;
    uint256 public totalSellFee;

    uint256 public maxFee;

    uint256 public swapAmount;

    mapping(address => bool) public _isExcludedFromFees;
    mapping(address => bool) public automatedMarketMakerPairs;

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event FeeWalletUpdated(string indexed name, address indexed newWallet);

    event SellFeeChange(string indexed name, uint256 newAm);

    event BuyFeeChange(string indexed name, uint256 newAm);

    event StuckTokenReleased();

    event SwapAmountChange(uint256 newAm);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event Withdraw();

    constructor(
        address _uniSwapRouterAddress,
        address[] memory _feeWallets
    ) ERC20("GROKI1", "GR1") {
        require(_feeWallets.length > 0);
        uniswapV2Router = IUniswapV2Router02(_uniSwapRouterAddress);

        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
                address(this),
                uniswapV2Router.WETH()
            );

        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

        sellFees["dev"] = 2;
        sellFees["market"] = 1;
        sellFees["lp"] = 1;

        buyFees["dev"] = 2;
        buyFees["market"] = 1;
        buyFees["lp"] = 1;

        feeWallets["dev"] = _feeWallets[0];
        feeWallets["market"] = _feeWallets[1];
        feeWallets["lp"] = _feeWallets[2];

        totalBuyFee = 4;
        totalSellFee = 4;
        maxFee = 10;

        uint256 totalSupply = 100_000_000 ether;

        swapAmount = 5000 ether;

        excludeFromFee(owner(), true);
        excludeFromFee(address(this), true);
        excludeFromFee(address(0xdead), true);

        _mint(_msgSender(), totalSupply);
    }

    function excludeFromFee(address who, bool isEx) public onlyOwner {
        require(_isExcludedFromFees[who] != isEx);
        _isExcludedFromFees[who] = isEx;
        emit ExcludeFromFees(who, isEx);
    }

    function setSellFees(string memory name, uint256 newAm) public onlyOwner {
        sellFees[name] = newAm;
        totalSellFee = sellFees["dev"] + sellFees["lp"] + sellFees["market"];
        require(
            totalBuyFee + totalSellFee <= maxFee,
            "Total fee should be less then max fee"
        );
        emit SellFeeChange(name, newAm);
    }

    function getSellFees(string memory name) public view returns (uint) {
        return sellFees[name];
    }

    function setBuyFees(string memory name, uint256 newAm) public onlyOwner {
        buyFees[name] = newAm;
        totalBuyFee = buyFees["dev"] + buyFees["lp"] + buyFees["market"];
        require(
            totalBuyFee + totalSellFee <= maxFee,
            "Total fee should be less then max fee"
        );
        emit BuyFeeChange(name, newAm);
    }

    function getBuyFees(string memory name) public view returns (uint) {
        return buyFees[name];
    }

    function setSwapAmount(uint256 newAm) public onlyOwner {
        require(swapAmount != newAm);
        swapAmount = newAm;
        emit SwapAmountChange(newAm);
    }

    function setFeeWallet(string memory name, address newAdd) public onlyOwner {
        require(feeWallets[name] != newAdd, "New address should be different");
        feeWallets[name] = newAdd;
        emit FeeWalletUpdated(name, newAdd);
    }

    function getFeeWallet(string memory name) public view returns (address) {
        return feeWallets[name];
    }

    function releaseStuckTokens(address _tokenAddress) public onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0);
        token.transfer(owner(), balance);
        emit StuckTokenReleased();
    }

    function setAutomatedMarketMakerPair(
        address pair,
        bool value
    ) public onlyOwner {
        require(
            pair != uniswapV2Pair,
            "The pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        _swapBack(from, to);

        if (!_isExcludedFromFees[from] || !_isExcludedFromFees[to]) {
            amount = _safeFee(from, to, amount);
        }

        super._transfer(from, to, amount);
    }

    function _swapBack(address from, address to) internal {
        uint256 thisBalance = balanceOf(address(this));
        uint256 tokensToSwap = feeAmounts["lp"] +
            feeAmounts["dev"] +
            feeAmounts["market"];

        bool swapAble = thisBalance >= swapAmount;
        bool success;

        if (thisBalance == 0 || tokensToSwap == 0) {
            return;
        }

        if (
            swapAble &&
            !automatedMarketMakerPairs[from] &&
            !_isExcludedFromFees[from] &&
            !_isExcludedFromFees[to]
        ) {
            uint256 initialBalance = address(this).balance;

            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = uniswapV2Router.WETH();

            _approve(address(this), address(uniswapV2Router), tokensToSwap);

            uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokensToSwap,
                0,
                path,
                address(this),
                block.timestamp
            );

            uint256 ethBalance = address(this).balance - initialBalance;
            uint256 ethMarket = (ethBalance * feeAmounts["market"]) /
                tokensToSwap;
            uint256 ethDev = (ethBalance * feeAmounts["dev"]) / tokensToSwap;

            feeAmounts["market"] = 0;
            feeAmounts["dev"] = 0;
            feeAmounts["lp"] = 0;

            (success, ) = address(feeWallets["dev"]).call{value: ethDev}("");
            (success, ) = address(feeWallets["market"]).call{value: ethMarket}(
                ""
            );
            (success, ) = address(feeWallets["lp"]).call{
                value: address(this).balance
            }("");
        }
    }

    function _safeFee(
        address from,
        address to,
        uint256 amount
    ) internal returns (uint256) {
        uint256 fee = 0;
        if (
            automatedMarketMakerPairs[to] &&
            totalSellFee > 0 &&
            !_isExcludedFromFees[from]
        ) {
            fee = (amount * totalSellFee) / 100;
            feeAmounts["lp"] += (amount * sellFees["lp"]) / 100;
            feeAmounts["dev"] += (amount * sellFees["dev"]) / 100;
            feeAmounts["market"] += (amount * sellFees["market"]) / 100;
        } else if (
            automatedMarketMakerPairs[from] &&
            totalBuyFee > 0 &&
            !_isExcludedFromFees[to]
        ) {
            fee = (amount * totalBuyFee) / 100;
            feeAmounts["lp"] += (amount * buyFees["lp"]) / 100;
            feeAmounts["dev"] += (amount * buyFees["dev"]) / 100;
            feeAmounts["market"] += (amount * buyFees["market"]) / 100;
        }

        if (fee > 0) {
            super._transfer(from, address(this), fee);
            amount -= fee;
        }
        return amount;
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;
        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function withdraw() public onlyOwner {
        require(address(this).balance > 0);
        bool success;
        (success, ) = address(owner()).call{value: address(this).balance}("");
        emit Withdraw();
    }

    receive() external payable {}
}
