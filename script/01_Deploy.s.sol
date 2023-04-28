// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import "forge-std/Script.sol";

import {UD60x18, sqrt} from "prb-math/UD60x18.sol";

import {Registrar} from "amplifi-v1-core/contracts/Registrar.sol";
import {Bookkeeper} from "amplifi-v1-core/contracts/Bookkeeper.sol";
import {PUD} from "amplifi-v1-core/contracts/PUD.sol";

import {Treasurer} from "amplifi-v1-periphery/Treasuer.sol";
import {PancakeOperator} from "amplifi-v1-periphery/PancakeOperator.sol";
import {UniswapV3Operator} from "amplifi-v1-periphery/UniswapV3Operator.sol";

import {AnvilKeys, BSCAddr} from "./00_EnvScript.s.sol";

contract Deploy is AnvilKeys, BSCAddr {
    function run() external broadcastWithPk(anvilPk0) {

	address registrar = address(new Registrar(amplifiSteward, WBNB));
	PUD pud = new PUD("Amplifi - PUD", "PUD", registrar);
	Bookkeeper bookkeeper = new Bookkeeper("Amplifi - NFT", "AMP", registrar);
	Treasurer treasurer = new Treasurer(registrar, pancakeNPM);

	PancakeOperator operator0 = new PancakeOperator(registrar, address(bookkeeper), pancakeNPM, pancakeSwapRouter);
	/* UniswapV3Operator operator1 = new UniswapV3Operator(registrar, address(bookkeeper), UniswapNPM, UniswapSwapRouter); */

	pud.initialize();
	bookkeeper.initialize();
	treasurer.initialize();

	string memory file = "env/contracts.env";
	vm.writeFile(file, string.concat("AMP_REGISTRAR=", vm.toString(registrar)));
	vm.writeLine(file, "");
	vm.writeLine(file, string.concat("AMP_BOOKKEEPER=", vm.toString(address(bookkeeper))));
	vm.writeLine(file, string.concat("AMP_PUD=", vm.toString(address(pud))));
	vm.writeLine(file, string.concat("AMP_TREASURER=", vm.toString(address(treasurer))));
	vm.writeLine(file, string.concat("AMP_PANCAKE_OPERATOR=", vm.toString(address(operator0))));
	/* vm.writeLine(file, string.concat("AMP_UNISWAP_OPERATOR=", vm.toString(address(operator1)))); */
	/* vm.writeLine(file, string.concat("PUD_USDC_POOL=", vm.toString(address(pool)))); */
    }
}
