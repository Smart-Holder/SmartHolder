//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import './Initializable.sol';
import './Interface.sol';

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts may inherit from this and call {_registerInterface} to declare
 * their support of an interface.
 */
contract ERC165 is Initializable, IERC165, IERC165_1 {
	/*
	 * bytes4(keccak256('supportsInterface(bytes4)')) == 0x01ffc9a7
	 */
	bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

	/**
	 * @dev Mapping of interface ids to whether or not it's supported.
	 */
	mapping(bytes4 => bool) private _supportedInterfaces;

	function initERC165() internal initializer {
		// Derived contracts need only register support for their own interfaces,
		// we register support for ERC165 itself here
		_registerInterface(_INTERFACE_ID_ERC165);
	}

	function checkInterface(bytes4 interfaceId, string memory message) view external override {
		require(supportsInterface(interfaceId), message);
	}

	/**
		* @dev See {IERC165-supportsInterface}.
		*
		* Time complexity O(1), guaranteed to always use less than 30 000 gas.
		*/
	function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
		return _supportedInterfaces[interfaceId];
	}

	/**
	 * @dev Registers the contract as an implementer of the interface defined by
	 * `interfaceId`. Support of the actual ERC165 interface is automatic and
	 * registering its interface id is not required.
	 *
	 * See {IERC165-supportsInterface}.
	 *
	 * Requirements:
	 *
	 * - `interfaceId` cannot be the ERC165 invalid interface (`0xffffffff`).
	 */
	function _registerInterface(bytes4 interfaceId) internal virtual {
		require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
		_supportedInterfaces[interfaceId] = true;
	}

	//uint256[49] private __gap;
}
