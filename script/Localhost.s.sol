// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import "forge-std/Script.sol";

import {Registrar} from "amplifi-v1-core/contracts/Registrar.sol";
import {Bookkeeper} from "amplifi-v1-core/contracts/Bookkeeper.sol";
import {Treasurer} from "amplifi-v1-periphery/Treasuer.sol";
import {Dispatcher} from "amplifi-v1-periphery/Dispatcher.sol";
import {PancakeOperator} from "amplifi-v1-periphery/PancakeOperator.sol";
import {UniswapV3Operator} from "amplifi-v1-periphery/UniswapV3Operator.sol";

import {AnvilKeys} from "../src/libraries/AnvilKeys.sol";
import {TestnetPUD, TestnetERC20} from "../src/TestnetERC20.sol";
import {TestnetConfigure} from "../src/TestnetConfigure.sol";

contract Deploy is Script {
    address private uniswapNPM = 0x7b8A01B39D58278b5DE7e48c8449c9f4F5170613;
    address private uniswapSwapRouter = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4; // TODO: find correct uniswap v3 swap router
    address private pancakeNPM = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
    address private pancakeSwapRouter = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;

    TestnetConfigure private configure;

    modifier broadcastWithPk(uint256 pk) {
        vm.startBroadcast(pk);
        _;
        vm.stopBroadcast();
    }

    function run() external {
        deploy();
        logAddressToENVFile("scripts_out/contracts.env");
        logAddressToJsonFile("scripts_out/contracts.json");
    }

    function deploy() internal broadcastWithPk(AnvilKeys.P0) {
        configure = new TestnetConfigure(AnvilKeys.A0);

        TestnetConfigure.TestnetContracts memory amp;

        amp.WBNB = address(new TestnetERC20("Testnet - WBNB", "FWBNB"));
        amp.USDC = address(new TestnetERC20("Testnet - USDC", "FUSDC"));
        amp.WETH = address(new TestnetERC20("Testnet - WETH", "FWETH"));

        amp.registry = address(new Registrar(address(configure), address(amp.WBNB)));
        amp.PUD = address(new TestnetPUD("Amplifi - PUD", "PUD", amp.registry));
        amp.bookkeeper = address(new Bookkeeper("Amplifi - NFT", "AMP", amp.registry));
        amp.treasurer = address(new Treasurer(amp.registry, pancakeNPM));
        amp.dispatcher = address(new Dispatcher(amp.registry));

        amp.Pancake_NFP = pancakeNPM;
        amp.Uniswap_NFP = uniswapNPM;

        amp.pancakeOperator = address(new PancakeOperator(amp.bookkeeper, pancakeNPM, pancakeSwapRouter));
        amp.uniswapOperator = address(new UniswapV3Operator(amp.bookkeeper, uniswapNPM, uniswapSwapRouter));

        configure.importAmplifi(amp);
        configure.defaults(AnvilKeys.A0, AnvilKeys.A1, AnvilKeys.A2);
    }

    function _s(address addr) internal pure returns (string memory) {
        return vm.toString(addr);
    }

    function logAddressToENVFile(string memory filepath) internal {
        TestnetConfigure.TestnetContracts memory amp;
        TestnetConfigure.DefaultSwapPools memory pools;
        (amp, pools) = configure.getContractAddr();

        string memory env = string.concat("AMP_CONFIGURE", _s(address(configure)), "\n");

        env = string.concat(env, "AMP_REGISTRAR=", _s(amp.registry), "\n");
        env = string.concat(env, "AMP_BOOKKEEPER=", _s(amp.bookkeeper), "\n");
        env = string.concat(env, "AMP_PUD=", _s(amp.PUD), "\n");
        env = string.concat(env, "AMP_TREASURER=", _s(amp.treasurer), "\n");
        env = string.concat(env, "AMP_DISPATCHER=", _s(amp.dispatcher), "\n");
        env = string.concat(env, "AMP_PANCAKE_OPERATOR=", _s(amp.pancakeOperator), "\n");
        env = string.concat(env, "AMP_UNISWAP_OPERATOR=", _s(amp.uniswapOperator), "\n");

        env = string.concat(env, "AMP_WBNB=", _s(amp.WBNB), "\n");
        env = string.concat(env, "AMP_USDC=", _s(amp.USDC), "\n");
        env = string.concat(env, "AMP_WETH=", _s(amp.WETH), "\n");

        env = string.concat(env, "AMP_WBNB_PUD=", _s(pools.WBNB_PUD), "\n");
        env = string.concat(env, "AMP_WBNB_USDC=", _s(pools.WBNB_USDC), "\n");
        env = string.concat(env, "AMP_WBNB_WETH=", _s(pools.WBNB_WETH), "\n");

        env = string.concat(env, "PANCAKE_NPM=", _s(amp.Pancake_NFP), "\n");
        env = string.concat(env, "UNISWAP_NPM=", _s(amp.Uniswap_NFP), "\n");

        vm.writeFile(filepath, env);
    }

    function logAddressToJsonFile(string memory filepath) internal {
        TestnetConfigure.TestnetContracts memory amp;
        TestnetConfigure.DefaultSwapPools memory pools;
        (amp, pools) = configure.getContractAddr();

        string memory json = "{\n";
        json = string.concat(json, "\"registrar\": \"", _s(amp.registry), "\"\n");
        json = string.concat(json, "\"bookkeeper\": \"", _s(amp.bookkeeper), "\"\n");
        json = string.concat(json, "\"pud\": \"", _s(amp.PUD), "\"\n");
        json = string.concat(json, "\"treasuer\": \"", _s(amp.treasurer), "\"\n");
        json = string.concat(json, "\"dispatcher\": \"", _s(amp.dispatcher), "\"\n");
        json = string.concat(json, "\"pancakeOperator\": \"", _s(amp.pancakeOperator), "\"\n");
        json = string.concat(json, "\"uniswapOperator\": \"", _s(amp.uniswapOperator), "\"\n");

        json = string.concat(json, "\"wbnb\": \"", _s(amp.WBNB), "\"\n");
        json = string.concat(json, "\"weth\": \"", _s(amp.WETH), "\"\n");
        json = string.concat(json, "\"usdc\": \"", _s(amp.USDC), "\"\n");

        json = string.concat(json, "\"pancakeNPM\": \"", _s(amp.Pancake_NFP), "\"\n");
        json = string.concat(json, "\"uniswapNPM\": \"", _s(amp.Uniswap_NFP), "\"\n");

        json = string.concat(json, "\"wbnbPud\": \"", _s(pools.WBNB_PUD), "\"\n");
        json = string.concat(json, "\"wbnbUsdc\": \"", _s(pools.WBNB_USDC), "\"\n");
        json = string.concat(json, "\"wbnbWeth\": \"", _s(pools.WBNB_WETH), "\"\n");
        json = string.concat(json, "}");

        vm.writeFile(filepath, json);
    }

    function logAddress() internal view {
        TestnetConfigure.TestnetContracts memory amp;
        (amp,) = configure.getContractAddr();

        console.log("Registrary:  %s", amp.registry);
        console.log("Bookkeeper:  %s", amp.bookkeeper);
        console.log("PUD:         %s", amp.PUD);
        console.log("Treasurer:   %s", amp.treasurer);
        console.log("Dispatcher:  %s", amp.dispatcher);
        console.log("PanOperator: %s", amp.pancakeOperator);
        console.log("UniOperator: %s", amp.uniswapOperator);
        console.log("WBNB:        %s", amp.WBNB);
        console.log("USDC:        %s", amp.USDC);
        console.log("WETH:        %s", amp.WETH);
    }
}
