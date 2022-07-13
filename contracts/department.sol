
pragma solidity ^0.8.15;

import "./dao.sol";
import "./vote_pool.sol";
import "./erc165.sol";
import "../openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol";

contract Department is ERC165 {
	using Address for address;

	/*
	 * bytes4(keccak256('initDepartment(address,string,address)')) == 0x36c6362d
	 */
	bytes4 private constant ID = 0x36c6362d;

	address private __impl;
	DAO internal host;
	string  public info;
	VotePool public operator;

	/**
		* @dev Throws if called by any account other than the owner.
		*/
	modifier OnlyDAO() {
		address sender = msg.sender;
		if (sender != operator) {
			if (sender != host.operator) {
				require(sender == host.root, "#Department#OnlyDAO caller does not have permission");
			}
		}
		_;
	}

	function initDepartment(address host_, string memory info_, address operator_) internal {
		initERC165();
		_registerInterface(ID);

		ERC165(host_).checkInterface(DAO.ID, "#Department#initDepartment dao host type not match");

		this.host = DAO(host_);
		this.info = info_;

		setOperator(operator_);
	}

	function setOperator(address vote) external OnlyDAO {
		if (vote != address(0)) {
			ERC165(vote).checkInterface(VotePool.ID, "#Department#setOperator operator type not match");
		}
		operator = VotePool(vote);
	}

	function upgrade(address impl) external OnlyDAO {
		__impl = impl;
	}

}