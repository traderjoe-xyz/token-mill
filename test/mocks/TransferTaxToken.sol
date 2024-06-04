// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/templates/BaseERC20.sol";

contract TransferTaxToken is BaseERC20 {
    uint256 public immutable tax;

    constructor(address factory_, uint256 tax_) BaseERC20(factory_) {
        require(tax_ <= 1e18, "TransferTaxToken: invalid tax");
        tax = tax_;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0)) {
            uint256 taxAmount = value * tax / 1e18;
            super._update(from, address(0), taxAmount);

            value -= taxAmount;
        }
        super._update(from, to, value);
    }
}
