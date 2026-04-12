import {Test} from "forge-std/Test.sol";
import { DeadSwitch } from "../../src/DeadSwitch.sol";

contract DeadSwitchTest is Test {
    DeadSwitch vault;
    address owner = makeAddr("owner");

    address yieldAdapter = makeAddr("yieldAdapter");
    address willRegistry = makeAddr("willRegistry");
    address streamEngine = makeAddr("streamEngine");

     function setUp() public {
        vault = new DeadSwitch(
            owner,
            yieldAdapter,
            willRegistry,
            streamEngine,
            30 days,   // checkInInterval
            7 days,    // warningPeriod
            3 days     // gracePeriod
        );
    }

    function testInitialStateIsActive() public view {
        assertEq(uint8(vault.getState()), uint8(0)); // Active = 0
    }

    function testCheckInUpdatesTimestamp() public {
        vm.warp(block.timestamp + 10 days);
        vm.prank(owner);
        vault.checkIn();
        assertEq(vault.getLastCheckIn(), block.timestamp);
    }

    function testNonOwnerCannotCheckIn() public {
        vm.prank(makeAddr("random"));
        vm.expectRevert();
        vault.checkIn();
    }

      function testTriggerWarningAfterInterval() public {
        vm.warp(block.timestamp + 31 days);
        vault.triggerWarning();
        assertEq(uint8(vault.getState()), uint8(1)); // Warning = 1
    }

     function testCannotTriggerWarningBeforeInterval() public {
        vm.warp(block.timestamp + 15 days);
        vm.expectRevert();
        vault.triggerWarning();
    }

        function testCheckInFromWarningResetsToActive() public {
        vm.warp(block.timestamp + 31 days);
        vault.triggerWarning();
        
        vm.prank(owner);
        vault.checkIn();
        assertEq(uint8(vault.getState()), uint8(0)); // Back to Active
    }

  function testFullStateMachine() public {
        // Active -> Warning
        vm.warp(block.timestamp + 31 days);
        vault.triggerWarning();

        // Warning -> GracePeriod
        vm.warp(block.timestamp + 7 days);
        vault.triggerGracePeriod();

        // Owner cancels
        vm.prank(owner);
        vault.cancelDistribution();
        assertEq(uint8(vault.getState()), uint8(0)); // Back to Active
    }

}