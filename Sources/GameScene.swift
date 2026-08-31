import SpriteKit
import UIKit

final class GameScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(
            red: 0.035,
            green: 0.04,
            blue: 0.055,
            alpha: 1
        )

        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = true

        buildTestScene()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        removeAllChildren()
        buildTestScene()
    }

    private func buildTestScene() {
        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = "ASHEN HOLLOW"
        title.fontSize = 30
        title.fontColor = .white
        title.position = CGPoint(
            x: size.width * 0.5,
            y: size.height * 0.62
        )
        addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Regular")
        subtitle.text = "Stage 1 • SpriteKit build test"
        subtitle.fontSize = 16
        subtitle.fontColor = UIColor(
            white: 0.72,
            alpha: 1
        )
        subtitle.position = CGPoint(
            x: size.width * 0.5,
            y: size.height * 0.56
        )
        addChild(subtitle)

        let platform = SKShapeNode(
            rectOf: CGSize(
                width: size.width * 0.72,
                height: 22
            ),
            cornerRadius: 4
        )
        platform.fillColor = UIColor(
            red: 0.16,
            green: 0.18,
            blue: 0.22,
            alpha: 1
        )
        platform.strokeColor = UIColor(
            white: 0.4,
            alpha: 0.45
        )
        platform.position = CGPoint(
            x: size.width * 0.5,
            y: size.height * 0.28
        )
        addChild(platform)

        let hero = SKShapeNode(
            rectOf: CGSize(
                width: 38,
                height: 58
            ),
            cornerRadius: 8
        )
        hero.fillColor = UIColor(
            red: 0.82,
            green: 0.84,
            blue: 0.88,
            alpha: 1
        )
        hero.strokeColor = .clear
        hero.position = CGPoint(
            x: size.width * 0.42,
            y: size.height * 0.28 + 40
        )
        addChild(hero)

        let eyes = SKShapeNode(
            rectOf: CGSize(
                width: 18,
                height: 5
            ),
            cornerRadius: 2
        )
        eyes.fillColor = UIColor(
            red: 0.55,
            green: 0.84,
            blue: 1,
            alpha: 1
        )
        eyes.strokeColor = .clear
        eyes.position = CGPoint(
            x: 0,
            y: 10
        )
        hero.addChild(eyes)

        let status = SKLabelNode(fontNamed: "AvenirNext-Medium")
        status.text = "BUILD OK"
        status.fontSize = 13
        status.fontColor = UIColor(
            red: 0.55,
            green: 0.9,
            blue: 0.65,
            alpha: 1
        )
        status.position = CGPoint(
            x: size.width * 0.5,
            y: size.height * 0.16
        )
        addChild(status)
    }
}
