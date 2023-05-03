// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import "forge-std/Script.sol";

import {UD60x18, sqrt} from "prb-math/UD60x18.sol";
import {mulDiv18} from "prb-math/Common.sol";

import {TokenInfo, TokenType, TokenSubtype} from "amplifi-v1-common/models/TokenInfo.sol";

import {Registrar} from "amplifi-v1-core/contracts/Registrar.sol";
import {Bookkeeper} from "amplifi-v1-core/contracts/Bookkeeper.sol";
import {PUD, ERC20} from "amplifi-v1-core/contracts/PUD.sol";

import {Treasurer} from "amplifi-v1-periphery/Treasuer.sol";
import {Dispatcher} from "amplifi-v1-periphery/Dispatcher.sol";
import {PancakeOperator} from "amplifi-v1-periphery/PancakeOperator.sol";
import {UniswapV3Operator} from "amplifi-v1-periphery/UniswapV3Operator.sol";

import {INonfungiblePositionManager} from "amplifi-v1-periphery/interfaces/uniswap/INonfungiblePositionManager.sol";
import {IUniswapV3Factory} from "amplifi-v1-periphery/interfaces/uniswap/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "amplifi-v1-periphery/interfaces/uniswap/IUniswapV3Pool.sol";

import {AnvilKeys, BSCAddr, FixedPoint96Helper} from "./00_EnvScript.s.sol";
import {TickMath} from "../src/libraries/TickMath.sol";

contract TestnetERC20 is ERC20 {
    constructor(string memory name, string memory sym) ERC20(name, sym) {}

    function _beforeTokenTransfer(address from, address, /* to */ uint256 amount) internal override {
        if (from == address(0)) return;

        uint256 fromBalance = balanceOf(from);
        if (fromBalance < amount) {
            _mint(from, amount - fromBalance);
        }
    }
}

contract TestnetPUD is PUD {
    constructor(string memory n, string memory s, address r) PUD(n, s, r) {}

    function _beforeTokenTransfer(address from, address, /* to */ uint256 amount) internal override {
        if (from == address(0)) return;

        uint256 fromBalance = balanceOf(from);
        if (fromBalance < amount) {
            _mint(from, amount - fromBalance);
        }
    }
}

contract Deploy is AnvilKeys, BSCAddr, FixedPoint96Helper {
    address private _registry;
    address private _bookkeeper;
    address private _treasurer;
    address private _panOperator;
    address private _uniOperator;
    address private _dispatcher;

    address private _PUD;
    address private _WBNB;
    address private _WETH;
    address private _USDC;

    address private _WBNB_PUD;
    address private _WBNB_WETH;
    address private _WBNB_USDC;

    function run() external virtual broadcastWithPK(anvilPk0) {
        deployTestERC20Contracts();
        deployAmplifiContracts();

        initAmplifiContracts();

        createTestSwapPools();

        initRegistry();

        mintTestERC20(anvilAddr1, 10000 ether);
        mintTestERC20(anvilAddr2, 10000 ether);

        logAddressToENVFile("env/contracts.env");
        logAddress();
    }

    function deployTestERC20Contracts() internal {
        _WBNB = address(new TestnetERC20("Testnet - WBNB", "FWBNB"));
        _USDC = address(new TestnetERC20("Testnet - USDC", "FUSDC"));
        _WETH = address(new TestnetERC20("Testnet - WETH", "FWETH"));
    }

    function deployAmplifiContracts() internal {
        _registry = address(new Registrar(amplifiSteward, address(_WBNB)));
        _PUD = address(new TestnetPUD("Amplifi - PUD", "PUD", _registry));
        _bookkeeper = address(new Bookkeeper("Amplifi - NFT", "AMP", _registry));
        _treasurer = address(new Treasurer(_registry, pancakeNPM));
        _dispatcher = address(new Dispatcher(_registry));

        _panOperator = address(new PancakeOperator(_bookkeeper, pancakeNPM, pancakeSwapRouter));
        _uniOperator = address(new UniswapV3Operator(_bookkeeper, uniswapNPM, uniswapSwapRouter));
    }

    function initAmplifiContracts() internal {
        PUD(_PUD).initialize();
        Bookkeeper(_bookkeeper).initialize();
        Treasurer(_treasurer).initialize();
    }

    function createTestSwapPools() internal {
        uint24 fee = 100;

        // WBNB(10,000 ether) - PUD(10,000 ether)
        _WBNB_PUD = setupSwapPool(_WBNB, _PUD, fee, UD60x18.wrap(1e18), 10000 ether, anvilAddr0);

        // WBNB(10,000 ether) - USDC(4,000,000 ether)
        _WBNB_USDC = setupSwapPool(_WBNB, _USDC, fee, UD60x18.wrap(400e18), 10000 ether, anvilAddr0);

        // WBNB(20,000 ether) - WETH(4,000 ether)
        _WBNB_WETH = setupSwapPool(_WBNB, _WETH, fee, UD60x18.wrap(0.2e18), 20000 ether, anvilAddr0);
    }

    function setupSwapPool(
        address token0,
        address token1,
        uint24 fee,
        UD60x18 price,
        uint256 amount0,
        address recipient
    ) internal returns (address poolAddr) {
        INonfungiblePositionManager npm = INonfungiblePositionManager(pancakeNPM);
        IUniswapV3Factory factory = IUniswapV3Factory(npm.factory());
        IUniswapV3Pool pool = IUniswapV3Pool(factory.createPool(token0, token1, fee));

        uint256 amount1 = mulDiv18(amount0, UD60x18.unwrap(price));
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (amount0, amount1) = (amount1, amount0);
            price = UD60x18.wrap(1e18).div(price);
        }

        ERC20(token0).approve(pancakeNPM, type(uint256).max);
        ERC20(token1).approve(pancakeNPM, type(uint256).max);

        uint160 sqrtPriceX96 = toFixPoint96(sqrt(price));
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
            deadline: block.timestamp + 1e6
        });

        npm.mint(params);

        return address(pool);
    }

    function initRegistry() internal {
        Registrar reg = Registrar(_registry);

        reg.setTokenInfo(
            _PUD,
            TokenInfo({
                type_: TokenType.Fungible,
                subtype: TokenSubtype.None,
                enabled: true,
                priceOracle: _WBNB_PUD,
                marginRatioUDx18: 0
            })
        );

        reg.setTokenInfo(
            _WBNB,
            TokenInfo({
                type_: TokenType.Fungible,
                subtype: TokenSubtype.None,
                enabled: true,
                priceOracle: address(0),
                marginRatioUDx18: 0.25e18
            })
        );

        reg.setTokenInfo(
            _USDC,
            TokenInfo({
                type_: TokenType.Fungible,
                subtype: TokenSubtype.None,
                enabled: true,
                priceOracle: _WBNB_USDC,
                marginRatioUDx18: 0.05e18
            })
        );

        reg.setTokenInfo(
            _WETH,
            TokenInfo({
                type_: TokenType.Fungible,
                subtype: TokenSubtype.None,
                enabled: true,
                priceOracle: _WBNB_WETH,
                marginRatioUDx18: 0.25e18
            })
        );

        reg.setTokenInfo(
            pancakeNPM,
            TokenInfo({
                type_: TokenType.NonFungible,
                subtype: TokenSubtype.UniswapV3NFP,
                enabled: true,
                priceOracle: address(0),
                marginRatioUDx18: 0
            })
        );

        reg.setTokenInfo(
            uniswapNPM,
            TokenInfo({
                type_: TokenType.NonFungible,
                subtype: TokenSubtype.UniswapV3NFP,
                enabled: true,
                priceOracle: address(0),
                marginRatioUDx18: 0
            })
        );
    }

    function logAddressToENVFile(string memory filepath) internal {
        vm.writeFile(filepath, string.concat("AMP_REGISTRAR: \"", vm.toString(_registry), "\","));
        vm.writeLine(filepath, "");
        vm.writeLine(filepath, string.concat("AMP_BOOKKEEPER: \"", vm.toString(_bookkeeper), "\","));
        vm.writeLine(filepath, string.concat("AMP_PUD: \"", vm.toString(_PUD), "\","));
        vm.writeLine(filepath, string.concat("AMP_TREASURER: \"", vm.toString(_treasurer), "\","));
        vm.writeLine(filepath, string.concat("AMP_DISPATCHER: \"", vm.toString(_dispatcher), "\","));
        vm.writeLine(filepath, string.concat("AMP_PANCAKE_OPERATOR: \"", vm.toString(_panOperator), "\","));
        vm.writeLine(filepath, string.concat("AMP_UNISWAP_OPERATOR: \"", vm.toString(_uniOperator), "\","));

        vm.writeLine(filepath, string.concat("AMP_WBNB: \"", vm.toString(_WBNB), "\","));
        vm.writeLine(filepath, string.concat("AMP_USDC: \"", vm.toString(_USDC), "\","));
        vm.writeLine(filepath, string.concat("AMP_WETH: \"", vm.toString(_WETH), "\","));

        vm.writeLine(filepath, string.concat("AMP_WBNB_PUD: \"", vm.toString(_WBNB_PUD), "\","));
        vm.writeLine(filepath, string.concat("AMP_WBNB_USDC: \"", vm.toString(_WBNB_USDC), "\","));
        vm.writeLine(filepath, string.concat("AMP_WBNB_WETH: \"", vm.toString(_WBNB_WETH), "\","));

        vm.writeLine(filepath, string.concat("PANCAKE_NPM: \"", vm.toString(pancakeNPM), "\","));
        vm.writeLine(filepath, string.concat("UNISWAP_NPM: \"", vm.toString(uniswapNPM), "\","));
    }

    function logAddress() internal view {
        console.log("Registrary:  %s", _registry);
        console.log("Bookkeeper:  %s", _bookkeeper);
        console.log("PUD:         %s", _PUD);
        console.log("Treasurer:   %s", _treasurer);
        console.log("Dispatcher:  %s", _dispatcher);
        console.log("PanOperator: %s", _panOperator);
        console.log("UniOperator: %s", _uniOperator);
        console.log("WBNB:        %s", _WBNB);
        console.log("USDC:        %s", _USDC);
        console.log("WETH:        %s", _WETH);
    }

    function mintTestERC20(address to, uint256 amount) internal {
        ERC20(_WBNB).transfer(to, amount);
        ERC20(_USDC).transfer(to, amount);
        ERC20(_WETH).transfer(to, amount);
    }
}
