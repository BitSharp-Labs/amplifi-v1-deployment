// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.19;

import {UD60x18, unwrap} from "prb-math/UD60x18.sol";
import {mulDiv18} from "prb-math/Common.sol";

import {MathHelper} from "amplifi-v1-periphery/utils/MathHelper.sol";

library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;

    function toFixPoint96(UD60x18 from) internal pure returns (uint160) {
        return uint160(mulDiv18(unwrap(from), FixedPoint96.Q96));
    }

    function fromFixPoint96(uint160 from) internal pure returns (UD60x18) {
        return UD60x18.wrap(MathHelper.mulDivRoundingUp(from, 1e18, FixedPoint96.Q96));
    }
}
