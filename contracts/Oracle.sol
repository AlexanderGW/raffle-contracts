pragma solidity ^0.8.0;

contract Oracle {
	address owner;
	uint public rand;

	constructor() public {
		owner = msg.sender;
		rand = uint(
			keccak256(
				abi.encodePacked(
					block.timestamp,
					block.difficulty,
					msg.sender
				)
			)
		);
	}

	function feedRandomness(uint _rand) external {
		require(msg.sender == owner);
		rand = uint(
			keccak256(
				abi.encodePacked(
					_rand,
					block.timestamp,
					block.difficulty,
					msg.sender
				)
			)
		);
	}
}