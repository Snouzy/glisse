import Testing
import CoreGraphics
@testable import GlisseCore

@Suite("Appareil")
struct DeviceTests {
    @Test func iPadScreenIsWiderAndShorterThanThePhone() {
        // L'iPad est en 4:3, l'iPhone beaucoup plus allongé : les deux tailles ne peuvent pas être confondues.
        #expect(Device.iPad.screenSize.width > Device.iPhone.screenSize.width)
        #expect(Device.iPad.screenSize.height < Device.iPhone.screenSize.height)
    }

    @Test func namesAreTheOnesPeopleRead() {
        #expect(Device.iPhone.name == "iPhone")
        #expect(Device.iPad.name == "iPad")
        #expect(Device.allCases.count == 2)
    }

    @Test func sizesLeaveRoomForTheCursor() {
        for device in Device.allCases {
            #expect(device.screenSize.width >= 400)
            #expect(device.screenSize.height >= 800)
        }
    }
}
