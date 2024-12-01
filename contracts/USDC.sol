// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract ManageLifeUSDC is ERC20, ERC20Permit {
    constructor()
        ERC20("ManageLife-USDC", "MLUSDC")
        ERC20Permit("ManageLife-USDT")
    {
        _mint(msg.sender, 100000 * 10 ** decimals());
    }
}
