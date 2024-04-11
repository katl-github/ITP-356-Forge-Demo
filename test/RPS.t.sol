// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { RPS, Move, Room, Player } from "../src/RPS.sol";

contract RPSTest is Test {
    // need to create an instance
    RPS internal _rps;

    event RoomStarted(string roomName, address player1, address player2);
    event MoveMade(string roomName);
    event MoveRevealed(string roomName, address player, Move move);
    event ResultRevealed(string roomName, address winner, address loser); // winner == loser == 0 means tie

    error RoomExists();
    error RoomDoesNotExist();
    error PlayerMismatch();
    error BeforeDeadline();
    error PastDeadline();
    error CannotReveal();
    error MoveMismatch();

    function setUp() public {
        _rps = new RPS();
    }

    function test_start() public {
        string memory roomName = "some room";
        address player2 = address(2);
        bytes32 hashedPlayer1Move = _rps.hashMove(Move.PAPER, "salt");
        // vm = testing framework
        vm.expectEmit();
        emit RoomStarted(roomName, address(this), player2);
        _rps.start(roomName, player2, hashedPlayer1Move);
        vm.expectRevert(abi.encodeWithSelector(RoomExists.selector));
        _rps.start(roomName, player2, hashedPlayer1Move);
    }

    function testFuzz_start(
        string memory roomName,
        address player1,
        address player2,
        uint8 move,
        string memory salt
    )
        public
    {
        vm.assume(move < 4);
        bytes32 hashedPlayer1Move = _rps.hashMove((Move(move)), salt);
        vm.prank(player1);
        vm.expectEmit();
        emit RoomStarted(roomName, player1, player2);
        _rps.start(roomName, player2, hashedPlayer1Move);
    }

    function test_play() public {
        string memory roomName = "some room";
        bytes32 hashedPlayer1Move = _rps.hashMove(Move.ROCK, "salt");
        bytes32 hashedPlayer2Move = _rps.hashMove(Move.PAPER, "salt");
        address player2 = address(2);

        vm.expectRevert(abi.encodeWithSelector(RoomDoesNotExist.selector));
        _rps.play(roomName, hashedPlayer2Move);

        _rps.start(roomName, player2, hashedPlayer1Move);

        address wrongPlayer = address(3);
        vm.expectRevert(abi.encodeWithSelector(PlayerMismatch.selector));

        vm.prank(wrongPlayer);
        _rps.play(roomName, hashedPlayer2Move);

        vm.expectEmit();
        emit MoveMade(roomName);
        vm.prank(player2);
        _rps.play(roomName, hashedPlayer2Move);

        vm.warp(block.timestamp + 2 minutes);
        vm.expectRevert(abi.encodeWithSelector(PastDeadline.selector));
        vm.prank(player2);
        _rps.play(roomName, hashedPlayer2Move);
    }

    function testFuzz_play(
        string memory roomName,
        address player1,
        address player2,
        address player3,
        uint8 move,
        string memory salt
    )
        public
    {
        vm.assume(move < 4);
        bytes32 hashedPlayer1Move = _rps.hashMove(Move(move), salt);
        bytes32 hashedPlayer2Move = _rps.hashMove(Move(move), salt);

        string memory wrongRoom = "wrong room";
        vm.expectRevert(abi.encodeWithSelector(RoomDoesNotExist.selector));
        vm.prank(player2);
        _rps.play(wrongRoom, hashedPlayer2Move);

        // Player Mismatch?
        // <if (room.player2 != msg.sender) revert PlayerMismatch();>

        // // vm.assume(wrongPlayer != player1 && wrongPlayer != player2);
        // // _rps.start(roomName, player3, hashedPlayer1Move);
        vm.assume(player3 != player2);

        vm.prank(player1);
        _rps.start(roomName, player2, hashedPlayer1Move);
        vm.prank(player3);
        vm.expectRevert(abi.encodeWithSelector(PlayerMismatch.selector));
        _rps.play(roomName, hashedPlayer2Move);

        // vm.prank(player1);
        // _rps.start(roomName, player2, hashedPlayer1Move);
        vm.prank(player2);
        vm.expectEmit();
        emit MoveMade(roomName);
        _rps.play(roomName, hashedPlayer2Move);

        vm.warp(block.timestamp + 2 minutes);
        vm.expectRevert(abi.encodeWithSelector(PastDeadline.selector));
        vm.prank(player2);
        _rps.play(roomName, hashedPlayer2Move);
    }

    function test_reveal() public {
        string memory roomName = "some room";
        bytes32 hashedPlayer1Move = _rps.hashMove(Move.ROCK, "salt");
        bytes32 hashedPlayer2Move = _rps.hashMove(Move.PAPER, "salt");
        address player2 = address(2);

        address player1 = msg.sender;
        vm.prank(player1);
        _rps.start(roomName, player2, hashedPlayer1Move);
        vm.prank(player2);
        _rps.play(roomName, hashedPlayer2Move);
        vm.prank(player1);
        vm.expectEmit();
        emit MoveRevealed(roomName, player1, Move.ROCK);
        _rps.reveal(roomName, Move.ROCK, "salt");

        // -----------------
        player2 = msg.sender;
        vm.prank(player2);
        vm.expectEmit();
        emit MoveRevealed(roomName, player2, Move.ROCK);
        _rps.reveal(roomName, Move.ROCK, "salt");

        // ------------------
        address wrongPlayer = address(3);
        vm.expectRevert(abi.encodeWithSelector(PlayerMismatch.selector));
        vm.prank(wrongPlayer);
        _rps.reveal(roomName, Move.ROCK, "salt");

        vm.warp(block.timestamp + 5 minutes);
        vm.expectRevert(abi.encodeWithSelector(CannotReveal.selector));
        vm.prank(player2);
        _rps.reveal(roomName, Move.PAPER, "salt");
    }

    function testFuzz_reveal(
        string memory roomName,
        address player1,
        address player2,
        address player3,
        uint8 move1,
        uint8 move2,
        string memory salt
    )
        public
    {
        vm.assume(move1 < 4);
        vm.assume(move2 < 4);

        bytes32 hashedPlayer1Move = _rps.hashMove(Move(move1), salt);
        bytes32 hashedPlayer2Move = _rps.hashMove(Move(move2), salt);

        vm.prank(player1);
        _rps.start(roomName, player2, hashedPlayer1Move);
        vm.prank(player2);
        _rps.play(roomName, hashedPlayer2Move);

        vm.prank(player1);
        vm.expectEmit();
        emit MoveRevealed(roomName, player1, Move(move1));
        _rps.reveal(roomName, Move(move1), salt);

        vm.prank(player2);
        vm.expectEmit();
        emit MoveRevealed(roomName, player2, Move(move2));
        _rps.reveal(roomName, Move(move2), salt);

        address player3 = player3;
        vm.expectRevert(abi.encodeWithSelector(PlayerMismatch.selector));
        vm.prank(player3);
        _rps.reveal(roomName, Move(move2), salt);

        vm.warp(block.timestamp + 5 minutes);
        vm.expectRevert(abi.encodeWithSelector(CannotReveal.selector));
        vm.prank(player2);
        _rps.reveal(roomName, Move(move2), salt);
    }

    function test_settleResults() public {
        string memory roomName = "some room";

        bytes32 hashedPlayer1Move = _rps.hashMove(Move.ROCK, "salt");
        bytes32 hashedPlayer2Move = _rps.hashMove(Move.PAPER, "salt");

        address player1 = address(1);
        address player2 = address(2);

        vm.prank(player1);
        _rps.start(roomName, player2, hashedPlayer1Move);
        vm.prank(player2);
        _rps.play(roomName, hashedPlayer2Move);

        vm.expectRevert(abi.encodeWithSelector(BeforeDeadline.selector));
        _rps.settleResults(roomName);

        vm.warp(block.timestamp + 100);

        _rps.settleResults(roomName);

        (address player1New, address player2New,,,,,,) = _rps.rooms(roomName);
        assertEq(player1New, address(0));
        assertEq(player2New, address(0));
    }

    function testFuzz_settleResult(
        string memory roomName,
        address player1,
        address player2,
        uint8 move1,
        uint8 move2,
        string memory salt
    )
        public
    {
        vm.assume(move1 < 4);
        vm.assume(move2 < 4);
        bytes32 hashedPlayer1Move = _rps.hashMove(Move(move1), salt);
        bytes32 hashedPlayer2Move = _rps.hashMove(Move(move2), salt);

        vm.prank(player1);
        _rps.start(roomName, player2, hashedPlayer1Move);
        vm.prank(player2);
        _rps.play(roomName, hashedPlayer2Move);

        vm.expectRevert(abi.encodeWithSelector(BeforeDeadline.selector));
        _rps.settleResults(roomName);

        vm.warp(block.timestamp + 100);

        _rps.settleResults(roomName);

        (address player1New, address player2New,,,,,,) = _rps.rooms(roomName);
        assertEq(player1New, address(0));
        assertEq(player2New, address(0));
    }

    function test_getResult() public {
        address player1 = address(1);
        address player2 = address(2);
        address blank = address(0);

        address winner;
        address loser;
        bool bothLose;

        (,, bothLose) = _rps.getResult(player1, Move.NONE, player2, Move.NONE);
        assertEq(bothLose, true);

        (winner, loser, bothLose) = _rps.getResult(player1, Move.PAPER, player2, Move.PAPER);
        assertEq(winner, blank);
        assertEq(loser, blank);
        assertEq(bothLose, false);

        (winner, loser, bothLose) = _rps.getResult(player1, Move.ROCK, player2, Move.PAPER);
        assertEq(winner, player2);
        assertEq(loser, player1);
        assertEq(bothLose, false);

        (winner, loser, bothLose) = _rps.getResult(player1, Move.ROCK, player2, Move.SCISSORS);
        assertEq(winner, player1);
        assertEq(loser, player2);
        assertEq(bothLose, false);

        (winner, loser, bothLose) = _rps.getResult(player1, Move.SCISSORS, player2, Move.ROCK);
        assertEq(winner, player2);
        assertEq(loser, player1);
        assertEq(bothLose, false);

        (winner, loser, bothLose) = _rps.getResult(player1, Move.SCISSORS, player2, Move.PAPER);
        assertEq(winner, player1);
        assertEq(loser, player2);
        assertEq(bothLose, false);

        // how to test for else? None???
    }

    function testFuzz_getResult(
        address player1,
        address player2,
        uint8 move1,
        uint8 move2,
        string memory salt
    )
        public
    {
        vm.assume(move1 < 4);
        vm.assume(move2 < 4);
        (address winner, address loser, bool bothLose) = _rps.getResult(player1, Move(move1), player2, Move(move2));
        assertEq(winner, winner);
        assertEq(loser, loser);
        assertEq(bothLose, bothLose);
    }

    function test_verifyMove() public {
        Move move = Move.SCISSORS;
        bytes32 hashedMove = _rps.hashMove(Move.PAPER, "salt");

        vm.expectRevert(MoveMismatch.selector);
        _rps.verifyMove(move, "salt", hashedMove);
    }

    function testFuzz_verifyMove(uint8 move1, uint8 move2, string memory salt) public {
        vm.assume(move1 < 4);
        vm.assume(move2 < 4);
        vm.assume(move1 != move2);
        bytes32 hashedMove = _rps.hashMove(Move(move2), salt);

        vm.expectRevert(MoveMismatch.selector);
        _rps.verifyMove(Move(move1), salt, hashedMove);
    }
}

// for each prank p1 for start and prank p2 for play
// for settleresults need to warp deadline+1
// assertEq for delete in settle results
