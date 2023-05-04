// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import {UD60x18, sqrt} from "prb-math/UD60x18.sol";
import {mulDiv18} from "prb-math/Common.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {TokenInfo, TokenType, TokenSubtype} from "amplifi-v1-common/models/TokenInfo.sol";

import {IRegistrar} from "amplifi-v1-common/interfaces/IRegistrar.sol";

import {INonfungiblePositionManager} from "amplifi-v1-periphery/interfaces/uniswap/INonfungiblePositionManager.sol";
import {IUniswapV3Factory} from "amplifi-v1-periphery/interfaces/uniswap/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "amplifi-v1-periphery/interfaces/uniswap/IUniswapV3Pool.sol";

import {TickMath} from "./libraries/TickMath.sol";
import {FixedPoint96} from "./libraries/FixedPoint96.sol";

interface Initializer {
    function initialize() external;
}

interface Stewardable {
    function appointSuccessor(address) external;
    function succeedSteward() external;
}

contract TestnetConfigure {
    address private owner;

    struct TestnetContracts {
	address registry;
	address bookkeeper;
	address treasurer;
	address pancakeOperator;
	address uniswapOperator;
	address dispatcher;
	address PUD;
	address WBNB;
	address WETH;
	address USDC;
	address Pancake_NFP;
	address Uniswap_NFP;
    }

    struct DefaultSwapPools {
	address WBNB_PUD;
	address WBNB_WETH;
	address WBNB_USDC;
    }

    TestnetContracts public amp;
    DefaultSwapPools public pools;

    constructor(address owner_) {
	owner = owner_;
    }

    function importAmplifi(TestnetContracts memory amp_) external {
	amp = amp_;
    }

    function getContractAddr() external view returns(TestnetContracts memory, DefaultSwapPools memory) {
	return (amp, pools);
    }

    function defaults(address liquidityRecipient, address testAddr1, address testAddr2) external {
	require(amp.registry != address(0), "deploy first.");

	this.initAmplifi();
	this.createDefaultTestSwapPools(liquidityRecipient);
	this.addDefaultTokenInfos();

	this.mintTestERC20(testAddr1, 10_000 ether);
	this.mintTestERC20(testAddr2, 10_000 ether);
    }

    function initAmplifi() external {
	Initializer(amp.PUD).initialize();
	Initializer(amp.bookkeeper).initialize();
	Initializer(amp.treasurer).initialize();
    }

    function createDefaultTestSwapPools(address recipient) external {
	require(amp.Pancake_NFP != address(0), "pancake npm needed.");

	uint24 fee = 100;

	// WBNB(10,000 ether) - PUD(10,000 ether)
	pools.WBNB_PUD =
	    this.createPool(amp.Pancake_NFP, amp.WBNB, amp.PUD, fee, UD60x18.wrap(1e18), 10000 ether, recipient);

	// WBNB(10,000 ether) - USDC(4,000,000 ether)
	pools.WBNB_USDC =
	    this.createPool(amp.Pancake_NFP, amp.WBNB, amp.USDC, fee, UD60x18.wrap(400e18), 10000 ether, recipient);

	// WBNB(20,000 ether) - WETH(4,000 ether)
	pools.WBNB_WETH =
	    this.createPool(amp.Pancake_NFP, amp.WBNB, amp.WETH, fee, UD60x18.wrap(0.2e18), 20000 ether, recipient);
    }

    function createPool(
	address npm_,
	address token0,
	address token1,
	uint24 fee,
	UD60x18 price,
	uint256 amount0,
	address recipient
    ) external returns (address poolAddr) {
	INonfungiblePositionManager npm = INonfungiblePositionManager(npm_);
	IUniswapV3Factory factory = IUniswapV3Factory(npm.factory());
	IUniswapV3Pool pool = IUniswapV3Pool(factory.createPool(token0, token1, fee));

	uint256 amount1 = mulDiv18(amount0, UD60x18.unwrap(price));
	if (token0 > token1) {
	    (token0, token1) = (token1, token0);
	    (amount0, amount1) = (amount1, amount0);
	    price = UD60x18.wrap(1e18).div(price);
	}

	IERC20(token0).approve(npm_, type(uint256).max);
	IERC20(token1).approve(npm_, type(uint256).max);

	uint160 sqrtPriceX96 = FixedPoint96.toFixPoint96(sqrt(price));
	pool.initialize(sqrtPriceX96);

	int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
	tick = tick / int24(fee) * int24(fee);

	INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
	    token0: token0,
	    token1: token1,
	    fee: fee,
	    tickLower: tick - int24(fee),
	    tickUpper: tick + int24(fee),
	    amount0Desired: amount0,
	    amount1Desired: amount1,
	    amount0Min: 0,
	    amount1Min: 0,
	    recipient: recipient,
	    deadline: block.timestamp
	});

	npm.mint(params);

	return address(pool);
    }

    function addTokenInfo(
	address token,
	TokenType type_,
	TokenSubtype subtype,
	address priceOracle,
	uint256 marginRatioUDx18
    ) external {
	require(amp.registry != address(0), "deploy first.");
	IRegistrar reg = IRegistrar(amp.registry);

	reg.setTokenInfo(
	    token,
	    TokenInfo({
		type_: type_,
		subtype: subtype,
		enabled: true,
		priceOracle: priceOracle,
		marginRatioUDx18: marginRatioUDx18
	    })
	);
    }

    function addDefaultTokenInfos() external {
	require(pools.WBNB_PUD != address(0), "createDefaultTestSwapPools first.");

	this.addTokenInfo(amp.PUD, TokenType.Fungible, TokenSubtype.None, pools.WBNB_PUD, 0);
	this.addTokenInfo(amp.WBNB, TokenType.Fungible, TokenSubtype.None, address(0), 0.25e18);
	this.addTokenInfo(amp.USDC, TokenType.Fungible, TokenSubtype.None, pools.WBNB_USDC, 0.05e18);
	this.addTokenInfo(amp.WETH, TokenType.Fungible, TokenSubtype.None, pools.WBNB_WETH, 0.25e18);
	this.addTokenInfo(amp.Pancake_NFP, TokenType.NonFungible, TokenSubtype.UniswapV3NFP, address(0), 0);
	this.addTokenInfo(amp.Uniswap_NFP, TokenType.NonFungible, TokenSubtype.UniswapV3NFP, address(0), 0);
    }

    function mintTestERC20(address to, uint256 amount) external {
	IERC20(amp.WBNB).transfer(to, amount);
	IERC20(amp.USDC).transfer(to, amount);
	IERC20(amp.WETH).transfer(to, amount);
    }

    function transferRegistryTo(address to) external {
	require(msg.sender == owner, "only owner");
	require(amp.registry != address(0), "not deploy");

	Stewardable(amp.registry).appointSuccessor(to);
    }

    function takeRegistryBack() external {
	Stewardable(amp.registry).succeedSteward();
    }
}
