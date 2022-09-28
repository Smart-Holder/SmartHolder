
pragma solidity >=0.6.0 <=0.8.15;

pragma experimental ABIEncoderV2;

import "./Interface.sol";
import "./ERC165.sol";
import "./Upgrade.sol";
import "../openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol";

contract VotePool is Upgrade, IVotePool, ERC165 {
	using Address for address;
	using SafeMath for uint256;

	bytes4 internal constant DAO_ID = 0xc7b55336;
	bytes4 internal constant VotePool_ID = 0x0ddf27bf;

	// define props
	IDAO private _host;
	string private _description;
	uint256 private _current; // 当前执行的提案决议
	// proposal id => Proposal
	mapping(uint256 => Proposal) private _proposalMap; // 提案决议列表
	uint256[] private _proposalList; // 提案列表索引
	// proposal id => map( member id => votes )
	mapping(uint256 => mapping(uint256 => int256)) private _votes; // 成员投票记录

	// @public
	uint256 public lifespan; // 提案生命周期限制

	function initVotePool(address host, uint256 _lifespan, string memory description) external {
		initERC165();
		_registerInterface(VotePool_ID);

		IDAO(host).checkInterface(DAO_ID, "#Department#initVotePool dao host type not match");
		_host = IDAO(host);
		_description = description;
		setLifespan(_lifespan);
	}

	function setLifespan(uint256 _lifespan) public OnlyDAO {
		require(_lifespan >= 7 days, "#VotePool#setLifespan proposal lifespan not less than 7 days");
		lifespan = _lifespan;
	}

	function host() view external returns (IDAO) {
		return _host;
	}

	function description() view external returns (string memory) {
		return _description;
	}

	function current() view public returns (uint256) {
		return _current;
	}

	function getProposal(uint256 id) view public returns (Proposal memory) {
		require(exists(id), "#VotePool#proposal proposal not exists");
		return _proposalMap[id];
	}

	function proposal(uint256 id) private returns (Proposal storage) {
		require(exists(id), "#VotePool#proposal proposal not exists");
		return _proposalMap[id];
	}

	function exists(uint256 id) view public returns (bool) {
		return _proposalMap[id].id != 0;
	}

	function create(Proposal memory proposal) public {
		require(!exists(proposal.id), "#VotePool#create proposal already exists");
		if (proposal.lifespan)
			require(proposal.lifespan >= lifespan, "#VotePool#create proposal lifespan not less than 7 days");
		require(proposal.passRate > 5_000, "#VotePool#create proposal vote pass rate not less than 50%");
		require(_host.member().tokenOfOwnerByIndex(msg.sender, 0) != 0, "#VotePool#create No call permission");

		if (proposal.loopCount != 0) {
			require(proposal.loopTime >= 1 minutes, "#VotePool#create Loop time must be greater than 1 minute");
		}
		Proposal storage obj = _proposalMap[proposal.id];

		obj.id = proposal.id;
		obj.name = proposal.name;
		obj.description = proposal.description;
		obj.target = proposal.target;
		obj.origin = msg.sender;
		obj.data = proposal.data;
		obj.lifespan = proposal.lifespan;
		obj.expiry = proposal.lifespan ? block.timestamp + proposal.lifespan: 0;
		obj.passRate = proposal.passRate > 10_000 ? 10_000: proposal.passRate;
		obj.loopCount = proposal.loopCount;
		obj.loopTime = proposal.loopTime;
		obj.voteTotal = 0;
		obj.agreeTotal = 0;
		obj.executeTime = 0;
		obj.idx = _proposalList.length;
		obj.isAgree = false;
		obj.isClose = false;
		obj.isExecuted = false;

		_proposalList.push(proposal.id);

		emit Created(proposal.id);
	}

	function create2(
		uint256 id,
		address target,
		uint256 lifespan,
		uint256 passRate,
		int256 loopCount,
		uint256 loopTime,
		string memory name,
		string memory description,
		bytes memory data
	) external {
		Proposal memory proposal;
		proposal.id = id;
		proposal.target = target;
		proposal.lifespan = lifespan;
		proposal.passRate = passRate;
		proposal.loopCount = loopCount;
		proposal.loopTime = loopTime;
		proposal.name = name;
		proposal.description = description;
		proposal.data = data;
		create(proposal);
	}

	function abs(int256 value) pure internal returns (uint256) {
		return value < 0 ? uint256(-value): uint256(value);
	}

	function vote(uint256 id, uint256 member, int256 votes) external {
		Proposal storage obj = proposal(id);
		IMember.Info memory info = _host.member().getInfo(member);

		require(votes != 0, "#VotePool#vote parameter error, votes==0");
		require(!obj.isClose, "#VotePool#vote Voting has been closed");
		require(_host.member().ownerOf(member) == msg.sender, "#VotePool#vote No call permission");
		require(_votes[id][member] == 0, "#VotePool#vote Cannot vote repeatedly");
		require(abs(votes) <= info.votes, "#VotePool#vote Voting limit");

		_votes[id][member] = votes;

		obj.voteTotal += abs(votes);

		if (votes > 0) {
			obj.agreeTotal += uint256(votes);
		}

		emit Vote(id, member, votes);

		tryClose(id); // try close
	}

	/**
	* @dev try close proposal
	*/
	function tryClose(uint256 id) public override {
		Proposal storage obj = proposal(id);
		require(!obj.isClose, "#VotePool#tryClose Voting has been closed");

		uint256 votes  = _host.member().votes();
		uint256 passRate = obj.passRate;

		if ((obj.expiry != 0 && obj.expiry <= block.timestamp)) { // block time expiry
			// Include only participating members
			obj.isClose = true;
			obj.isAgree = (obj.agreeTotal * 10_000 / obj.voteTotal) > passRate;
		} else {
			if ((obj.agreeTotal * 10_000 / votes) > passRate) { // test passRate
				obj.isClose = true;
				obj.isAgree = true; // complete
			} else if (((obj.voteTotal - obj.agreeTotal) * 10_000 / votes) > 10_000 - passRate) { // test rejectRate
				obj.isClose = true;
				obj.isAgree = false; // complete
			}
		}

		if (obj.isClose) {
			emit Close(id);
			if (obj.isAgree) {
				execute(id);
			}
		}
	}

	function execute(uint256 id) public {
		Proposal storage obj = proposal(id);

		require(obj.isAgree, "#VotePool#execute Proposal was not passed");
		require(!obj.isExecuted, "#VotePool#execute Resolution has been implemented");

		if (obj.loopCount != 0) {
			require(obj.executeTime + obj.loopTime < block.timestamp, "#VotePool#execute Execution interval is too short");
			if (obj.loopCount > 0) {
				execCall(obj);
				obj.loopCount--;
			} else { // permanent loop
				execCall(obj);
			}
		} else { // execute once
			execCall(obj);
			obj.isExecuted = true;
		}

		obj.executeTime = block.timestamp;

		emit Execute(id);
	}

	function execCall(Proposal storage obj) internal {
		_current = obj.id;
		(bool suc, bytes memory _data) = obj.target.call{ value: msg.value }(obj.data);
		_current = 0;

		assembly {
			let len := mload(_data)
			let data := add(_data, 0x20)
			switch suc
			case 0 { revert(data, len) }
			default { 
				// return(data, len) 
			}
		}
	}

	function total() view public returns (uint256) {
		return _proposalList.length;
	}

}