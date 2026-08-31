import SwiftUI
import SpriteKit

struct GameView: View {
    private var scene: SKScene {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
        return scene
    }

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .background(Color.black)
    }
}
