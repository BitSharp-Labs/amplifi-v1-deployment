// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import {PUD as _PUD, ERC20} from "amplifi-v1-core/contracts/PUD.sol";

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

contract TestnetPUD is _PUD {
    constructor(string memory n, string memory s, address r) _PUD(n, s, r) {}

    function _beforeTokenTransfer(address from, address, /* to */ uint256 amount) internal override {
        if (from == address(0)) return;

        uint256 fromBalance = balanceOf(from);
        if (fromBalance < amount) {
            _mint(from, amount - fromBalance);
        }
    }
}
