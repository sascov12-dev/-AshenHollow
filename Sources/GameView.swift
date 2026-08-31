import SwiftUI
import SpriteKit

struct GameView: View {

    @State private var scene: GameScene = {
        let scene = GameScene(
            size: CGSize(width: 844, height: 390)
        )
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        SpriteView(
            scene: scene,
            options: [.ignoresSiblingOrder]
        )
        .ignoresSafeArea()
        .background(Color.black)
    }
}
