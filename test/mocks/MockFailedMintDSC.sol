// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockFailedMintDSC is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__AmountMustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    /**
     * @notice Constructor sets the token name and symbol, and initializes the owner to msg.sender.
     */
    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    /**
     * @notice Only the owner can burn tokens. Reverts if _amount is zero or if the balance is insufficient.
     */
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount == 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    /**
     * @notice Mints `_amount` tokens to address `_to`. Only the owner can call this function.
     * @dev Always returns false to simulate a mint failure.
     */
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if (_amount == 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        // Simulate mint failure by always returning false
        return false;
    }
}
