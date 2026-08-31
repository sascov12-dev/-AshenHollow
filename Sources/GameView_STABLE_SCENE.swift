import SwiftUI
import SpriteKit

struct GameView: View {
    // Keep ONE scene instance for the entire lifetime of this view.
    // Do not rebuild the SpriteKit scene from a computed property.
    private let gameScene: GameScene

    init() {
        let scene = GameScene(size: CGSize(width: 844, height: 390))
        scene.scaleMode = .resizeFill
        self.gameScene = scene
    }

    var body: some View {
        SpriteView(
            scene: gameScene,
            options: [.ignoresSiblingOrder]
        )
        .ignoresSafeArea()
        .background(Color.black)
    }
}
