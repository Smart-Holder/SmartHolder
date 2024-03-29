// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// import '../openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import './libs/Ownable.sol';
// Module impl
import './DAO.sol';
import './Asset.sol';
import './AssetShell.sol';
import './Ledger.sol';
import './Member.sol';
import './VotePool.sol';
// Proxy
import './gen/DAOProxy.sol';
import './gen/AssetProxy.sol';
import './gen/AssetShellProxy.sol';
import './gen/LedgerProxy.sol';
import './gen/MemberProxy.sol';
import './gen/VotePoolProxy.sol';

/**
 * @title DAOs contract global DAOs manage
 */
contract DAOs is Upgrade, Initializable, Ownable, IDAOs {
	using EnumerableSet for EnumerableSet.AddressSet;

	struct DAOIMPLs {
		address   DAO;
		address   Member;
		address   VotePool;
		address   Ledger;
		address   Asset;
		address   AssetShell;
	}

	struct InitMemberArgs {
		string name;
		string description;
		Member.MintMemberArgs[] members;
	}

	struct InitVotePoolArgs {
		string  description;
		uint256 lifespan;
	}

	struct InitLedgerArgs {
		string  description;
	}

	struct InitAssetArgs {
		string  name;
		string  description;
		string  image;
		string  external_link;
		uint32  seller_fee_basis_points_first;
		uint32  seller_fee_basis_points_second;
		address fee_recipient;
		string  contractURIPrefix;
	}

	EnumerableSet.AddressSet private  _DAOs; // global DAOs list
	DAOIMPLs                 public   defaultIMPLs; // default logic impl
	uint256[50]              private  __; // reserved storage space

	function initDAOs() external initializer {
		initOwnable();
	}

	function setDefaultIMPLs(DAOIMPLs memory IMPLs) public onlyOwner {
		defaultIMPLs = IMPLs;
	}

	/**
	 * @dev deploy() deploy common voting DAO
	 */
	function deploy(
		string           memory    name,              string           memory    mission,
		string           memory    description,       address                    operator,
		InitMemberArgs   memory    memberArgs,        InitVotePoolArgs memory    votePoolArgs
	) external returns (IDAO) {
		DAO host      = DAO( address(new DAOProxy(defaultIMPLs.DAO)) );
		Member member = Member( address(new MemberProxy(defaultIMPLs.Member)) );
		VotePool root = VotePool( address(new VotePoolProxy(defaultIMPLs.VotePool)) );

		member.initMember(address(host), memberArgs.name, memberArgs.description, address(0), memberArgs.members);
		root.initVotePool(address(host), votePoolArgs.description, votePoolArgs.lifespan);
		host.initDAO(name, mission, description, address(root), operator, address(member));

		emit Created(address(host));

		return host;
	}

	/**
	 * @dev makeAssetSales() deploy asset sales DAO
	 */
	function deployAssetSalesDAO(
		string             memory    name,              string             memory    mission,
		string             memory    description,       address                      operator,
		InitMemberArgs     memory    memberArgs,        InitVotePoolArgs   memory    votePoolArgs,
		InitLedgerArgs     memory    ledgerArgs,        InitAssetArgs      memory    assetArgs
	) external returns (IDAO) {

		DAO host      = DAO( address(new DAOProxy(defaultIMPLs.DAO)) );
		Member member = Member( address(new MemberProxy(defaultIMPLs.Member)) );
		VotePool root = VotePool( address(new VotePoolProxy(defaultIMPLs.VotePool)) );

		member.initMember(address(host), memberArgs.name, memberArgs.description, address(0), memberArgs.members);
		root.initVotePool(address(host), votePoolArgs.description, votePoolArgs.lifespan);
		host.initDAO(name, mission, description, address(root), address(this), address(member));

		// sales
		Ledger ledger = Ledger( payable(address(new LedgerProxy(defaultIMPLs.Ledger))) );
		Asset  asset = Asset( address(new AssetProxy(defaultIMPLs.Asset)));
		AssetShell  assetFirst = AssetShell( payable(address(new AssetShellProxy(defaultIMPLs.AssetShell))));
		AssetShell  assetSecond = AssetShell( payable(address(new AssetShellProxy(defaultIMPLs.AssetShell))));

		AssetBase.InitContractURI memory uri;
		uri.name                    = assetArgs.name;
		uri.description             = assetArgs.description;
		uri.image                   = assetArgs.image;
		uri.external_link           = assetArgs.external_link;
		uri.seller_fee_basis_points = assetArgs.seller_fee_basis_points_second;
		uri.fee_recipient           = assetArgs.fee_recipient;
		uri.contractURIPrefix       = assetArgs.contractURIPrefix;

		ledger.initLedger(address(host), ledgerArgs.description, address(0));
		asset.initAsset(address(host), address(0), uri);
		assetSecond.initAssetShell(address(host), address(0), IAssetShell.SaleType.kSecond, uri);

		uri.seller_fee_basis_points = assetArgs.seller_fee_basis_points_first;

		assetFirst.initAssetShell(address(host), address(0), IAssetShell.SaleType.kFirst, uri);

		// set modules
		host.setModule(Module_LEDGER_ID, address(ledger));
		host.setModule(Module_ASSET_ID, address(asset));
		host.setModule(Module_ASSET_First_ID, address(assetFirst));
		host.setModule(Module_ASSET_Second_ID, address(assetSecond));

		host.setOperator(operator); // change to raw operator

		emit Created(address(host));

		return host;
	}

	/**
	 * @dev length() Returns DAOs length
	 */
	function length() view public returns (uint256) {
		return _DAOs.length();
	}

	/**
	 * @dev contains(address) is contains dao address
	 */
	function contains(address addr) view public returns (bool) {
		return _DAOs.contains(addr);
	}

	/**
	 * @dev at(id) get DAO object from index
	 * @param index uint256 dao index
	 * @return Returns the IDAO interface address
	 */
	function at(uint256 index) view external returns (IDAO) {
		return IDAO(_DAOs.at(index));
	}

	/**
	 * @dev upgrade(address) upgrade contracts
	 */
	function upgrade(address impl) public onlyOwner {
		_impl = impl;
	}
}