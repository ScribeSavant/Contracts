//SPDX-License-Identifier: MIT

//         GGGGGGGGGGGGGRRRRRRRRRRRRRRRRR        OOOOOOOOO     KKKKKKKKK    KKKKKKK
//      GGG::::::::::::GR::::::::::::::::R     OO:::::::::OO   K:::::::K    K:::::K
//    GG:::::::::::::::GR::::::RRRRRR:::::R  OO:::::::::::::OO K:::::::K    K:::::K
//   G:::::GGGGGGGG::::GRR:::::R     R:::::RO:::::::OOO:::::::OK:::::::K   K::::::K
//  G:::::G       GGGGGG  R::::R     R:::::RO::::::O   O::::::OKK::::::K  K:::::KKK
// G:::::G                R::::R     R:::::RO:::::O     O:::::O  K:::::K K:::::K
// G:::::G                R::::RRRRRR:::::R O:::::O     O:::::O  K::::::K:::::K
// G:::::G    GGGGGGGGGG  R:::::::::::::RR  O:::::O     O:::::O  K:::::::::::K
// G:::::G    G::::::::G  R::::RRRRRR:::::R O:::::O     O:::::O  K:::::::::::K
// G:::::G    GGGGG::::G  R::::R     R:::::RO:::::O     O:::::O  K::::::K:::::K
// G:::::G        G::::G  R::::R     R:::::RO:::::O     O:::::O  K:::::K K:::::K
//  G:::::G       G::::G  R::::R     R:::::RO::::::O   O::::::OKK::::::K  K:::::KKK
//   G:::::GGGGGGGG::::GRR:::::R     R:::::RO:::::::OOO:::::::OK:::::::K   K::::::K
//    GG:::::::::::::::GR::::::R     R:::::R OO:::::::::::::OO K:::::::K    K:::::K
//      GGG::::::GGG:::GR::::::R     R:::::R   OO:::::::::OO   K:::::::K    K:::::K
//         GGGGGG   GGGGRRRRRRRR     RRRRRRR     OOOOOOOOO     KKKKKKKKK    KKKKKKK

/**
 * Links
 * Website: https://grok-pls.com
 * Telegram: https://t.me/GrokPulse
 * Twitter: https://x.com/GrokPulse
 */

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.0;

interface IPulseXRouter02 {
    function factory() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function WPLS() external pure returns (address);
}

interface IPulseXFactory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint
    );

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

contract GROK is ERC20, Ownable {
    using SafeMath for uint256;

    IPulseXRouter02 public pulseV2Router;
    address public pulseV2Pair;

    address public feeWallet;

    uint256 public feeAmount;

    uint256 public buyFee;
    uint256 public sellFee;

    uint256 public maxWallet;
    uint256 public maxTransaction;
    uint256 public swapAmount;

    bool public swapEnabled;
    uint256 public swapEnabledBlock;
    uint256 public blockLimit;

    mapping(address => bool) public _isExcludedFromFees;
    mapping(address => bool) public _isExcludedFromMaxTransactionAmount;
    mapping(address => bool) public _isExcludedFromWalletAmount;
    mapping(address => bool) public automatedMarketMakerPairs;

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event FeeWalletUpdated(
        address indexed oldWallet,
        address indexed newWallet
    );

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    modifier checkMax(
        address from,
        address to,
        uint256 amount
    ) {
        if (
            from != owner() &&
            to != owner() &&
            to != address(0) &&
            to != address(0xdead) &&
            maxTransaction > 0 &&
            maxWallet > 0
        ) {
            if (
                automatedMarketMakerPairs[from] &&
                !_isExcludedFromMaxTransactionAmount[to]
            ) {
                require(amount < maxTransaction, "Max transaction exceeded!");
                require(
                    balanceOf(to) + amount < maxWallet,
                    "Max wallet exceeded!"
                );
            } else if (
                automatedMarketMakerPairs[to] &&
                !_isExcludedFromMaxTransactionAmount[from]
            ) {
                require(amount < maxTransaction, "Max transaction exceeded!");
            } else if (!_isExcludedFromWalletAmount[to]) {
                require(
                    balanceOf(to) + amount < maxWallet,
                    "Max wallet exceeded!"
                );
            }
        }
        _;
    }

    constructor(
        address _pulseSwapRouterAddress,
        address _feeWallet
    ) ERC20("GROK", "GPLS") {
        pulseV2Router = IPulseXRouter02(_pulseSwapRouterAddress);
        excludedFromMaxTransactionAmount(address(pulseV2Router), true);

        pulseV2Pair = IPulseXFactory(pulseV2Router.factory()).createPair(
            address(this),
            pulseV2Router.WPLS()
        );

        excludedFromMaxTransactionAmount(address(pulseV2Pair), true);
        excludedFromWalletAmount(address(pulseV2Pair), true);
        _setAutomatedMarketMakerPair(address(pulseV2Pair), true);

        // fee
        feeWallet = _feeWallet;
        buyFee = 6;
        sellFee = 6;

        uint256 totalSupply = 1_000_000 ether;
        maxTransaction = 20000 ether;
        maxWallet = 20000 ether;
        swapAmount = 5000 ether;
        swapEnabled = false;
        blockLimit = 2;

        excludeFromFee(owner(), true);
        excludeFromFee(address(this), true);
        excludeFromFee(address(0xdead), true);

        excludedFromMaxTransactionAmount(owner(), true);
        excludedFromMaxTransactionAmount(address(this), true);
        excludedFromMaxTransactionAmount(address(0xdead), true);

        excludedFromWalletAmount(owner(), true);
        excludedFromWalletAmount(address(this), true);
        excludedFromWalletAmount(address(0xdead), true);

        _mint(_msgSender(), totalSupply);
    }

    function excludeFromFee(address who, bool isEx) public onlyOwner {
        _isExcludedFromFees[who] = isEx;
        emit ExcludeFromFees(who, isEx);
    }

    function excludedFromMaxTransactionAmount(
        address who,
        bool isEx
    ) public onlyOwner {
        _isExcludedFromMaxTransactionAmount[who] = isEx;
    }

    function excludedFromWalletAmount(address who, bool isEx) public onlyOwner {
        _isExcludedFromWalletAmount[who] = isEx;
    }

    function setMaxWallet(uint256 newAm) public onlyOwner {
        maxWallet = newAm;
    }

    function setMaxTransaction(uint256 newAm) public onlyOwner {
        maxTransaction = newAm;
    }

    function setBuyFees(uint256 newAm) public onlyOwner {
        require(newAm < 40, "Total fee should be less then %40");
        buyFee = newAm;
    }

    function setSellFees(uint256 newAm) public onlyOwner {
        require(newAm < 40, "Total fee should be less then %40");
        sellFee = newAm;
    }

    function setSwapAmount(uint256 newAm) public onlyOwner {
        swapAmount = newAm;
    }

    function enableSwap() public onlyOwner {
        swapEnabled = true;
        swapEnabledBlock = block.number;
    }

    function setFeeWallet(address newAdd) public onlyOwner {
        address oldWallet = feeWallet;
        feeWallet = newAdd;
        emit FeeWalletUpdated(oldWallet, newAdd);
    }

    function releaseStuckTokens(address _tokenAddress) public onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.transfer(owner(), balance);
        }
    }

    function setAutomatedMarketMakerPair(
        address pair,
        bool value
    ) public onlyOwner {
        require(
            pair != pulseV2Pair,
            "The pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override checkMax(from, to, amount) {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (
            (automatedMarketMakerPairs[to] &&
                !swapEnabled &&
                from != owner()) ||
            (automatedMarketMakerPairs[from] && !swapEnabled && to != owner())
        ) {
            revert("Swap disabled");
        }

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
        uint256 tokensToSwap = feeAmount;
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
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = pulseV2Router.WPLS();

            _approve(address(this), address(pulseV2Router), tokensToSwap);

            pulseV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokensToSwap,
                0,
                path,
                address(this),
                block.timestamp
            );

            feeAmount = 0;
            (success, ) = address(feeWallet).call{value: address(this).balance}(
                ""
            );
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
            sellFee > 0 &&
            !_isExcludedFromFees[from]
        ) {
            if ((swapEnabledBlock + blockLimit) >= block.number) {
                fee = (amount * 99) / 100;
            } else {
                fee = (amount * sellFee) / 100;
            }
            feeAmount += fee;
        } else if (
            automatedMarketMakerPairs[from] &&
            buyFee > 0 &&
            !_isExcludedFromFees[to]
        ) {
            if ((swapEnabledBlock + blockLimit) >= block.number) {
                fee = (amount * 99) / 100;
            } else {
                fee = (amount * buyFee) / 100;
            }
            feeAmount += fee;
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

    function withdraw() public onlyOwner returns (bool) {
        bool success;
        (success, ) = address(owner()).call{value: address(this).balance}("");
        return success;
    }

    receive() external payable {}
}
