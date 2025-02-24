// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockFailedTransferFrom is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__AmountMustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    /**
     * @notice Parameterless constructor that initializes the token and sets the deployer as the owner.
     * In future versions of OpenZeppelin Ownable, the owner must be passed explicitly.
     * Here we pass msg.sender, which in tests (using vm.prank) will be the expected owner.
     */
    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    /**
     * @notice Burns `_amount` tokens from the caller's balance.
     * Only the owner is allowed to burn.
     */
    function burn(uint256 _amount) public override onlyOwner {
        if (_amount == 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        if (balanceOf(msg.sender) < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    /**
     * @notice Mints `amount` tokens to the specified account.
     * Only the owner can mint.
     */
    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    /**
     * @notice Overrides transferFrom to always return false, simulating a failed transfer.
     */
    function transferFrom(address, /* sender */ address, /* recipient */ uint256 /* amount */ )
        public
        pure
        override
        returns (bool)
    {
        return false;
    }
}
