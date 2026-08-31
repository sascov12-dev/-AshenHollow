import SpriteKit
import UIKit

final class GameScene: SKScene {

    // MARK: - Physics categories

    private enum PhysicsCategory {
        static let player: UInt32 = 1 << 0
        static let world: UInt32  = 1 << 1
    }

    // MARK: - Nodes

    private let player = SKShapeNode(
        rectOf: CGSize(width: 42, height: 64),
        cornerRadius: 10
    )

    private let playerVisual = SKNode()
    private let gameCamera = SKCameraNode()
    private let hud = SKNode()

    private var platforms: [SKShapeNode] = []
    private var worldWidth: CGFloat = 2200

    // MARK: - Movement

    private let runSpeed: CGFloat = 315
    private let groundAcceleration: CGFloat = 1900
    private let airAcceleration: CGFloat = 1050
    private let groundDeceleration: CGFloat = 2400

    private let jumpVelocity: CGFloat = 610
    private let maxFallSpeed: CGFloat = -900

    private var moveInput: CGFloat = 0
    private var targetMoveInput: CGFloat = 0
    private var facing: CGFloat = 1

    // MARK: - Jump state

    private var isGrounded = false

    private let coyoteDuration: TimeInterval = 0.12
    private var coyoteTimer: TimeInterval = 0

    private let jumpBufferDuration: TimeInterval = 0.12
    private var jumpBufferTimer: TimeInterval = 0

    private var jumpHeld = false
    private var didCutJump = false

    // MARK: - Timing

    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Camera

    private let cameraZoom: CGFloat = 1.55
    private let cameraFollowSpeed: CGFloat = 4.2
    private let cameraLookAhead: CGFloat = 120
    private let cameraVerticalOffset: CGFloat = 22

    // MARK: - Controls

    private let leftButton = SKShapeNode(circleOfRadius: 43)
    private let rightButton = SKShapeNode(circleOfRadius: 43)
    private let jumpButton = SKShapeNode(circleOfRadius: 51)

    private let leftArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let rightArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let jumpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let buildLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var leftTouches = Set<ObjectIdentifier>()
    private var rightTouches = Set<ObjectIdentifier>()
    private var jumpTouches = Set<ObjectIdentifier>()

    // MARK: - Scene lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(
            red: 0.025,
            green: 0.03,
            blue: 0.045,
            alpha: 1
        )

        view.ignoresSiblingOrder = true

        // Keep rendering simple and predictable while we debug gameplay.
        view.shouldCullNonVisibleNodes = false
        view.isMultipleTouchEnabled = true

        physicsWorld.gravity = CGVector(dx: 0, dy: -1700)

        buildWorld()
        buildPlayer()
        buildCamera()
        buildHUD()
        layoutHUD()

        // Give the body one physics frame to settle, but also seed a short
        // coyote window so JUMP works immediately after the scene appears.
        coyoteTimer = coyoteDuration
        updateGroundedState()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutHUD()
    }

    // MARK: - World

    private func buildWorld() {
        platforms.removeAll()

        worldWidth = max(2200, size.width * 3.0)

        let backdrop = SKShapeNode(
            rectOf: CGSize(
                width: worldWidth,
                height: max(size.height, 520)
            )
        )
        backdrop.fillColor = UIColor(
            red: 0.035,
            green: 0.042,
            blue: 0.06,
            alpha: 1
        )
        backdrop.strokeColor = .clear
        backdrop.position = CGPoint(
            x: worldWidth * 0.5,
            y: max(size.height, 520) * 0.5
        )
        backdrop.zPosition = -100
        addChild(backdrop)

        for index in 0..<12 {
            let pillar = SKShapeNode(
                rectOf: CGSize(
                    width: 62 + CGFloat(index % 3) * 18,
                    height: 170 + CGFloat(index % 4) * 45
                ),
                cornerRadius: 16
            )

            pillar.fillColor = UIColor(
                red: 0.07,
                green: 0.08,
                blue: 0.11,
                alpha: 0.72
            )
            pillar.strokeColor = .clear
            pillar.position = CGPoint(
                x: 120 + CGFloat(index) * 175,
                y: 115 + pillar.frame.height * 0.5
            )
            pillar.zPosition = -50

            addChild(pillar)
        }

        addPlatform(
            center: CGPoint(x: worldWidth * 0.5, y: 60),
            size: CGSize(width: worldWidth, height: 80)
        )

        addPlatform(
            center: CGPoint(x: 520, y: 190),
            size: CGSize(width: 260, height: 28)
        )

        addPlatform(
            center: CGPoint(x: 900, y: 255),
            size: CGSize(width: 230, height: 28)
        )

        addPlatform(
            center: CGPoint(x: 1320, y: 175),
            size: CGSize(width: 310, height: 28)
        )

        addPlatform(
            center: CGPoint(x: 1740, y: 235),
            size: CGSize(width: 260, height: 28)
        )
    }

    private func addPlatform(
        center: CGPoint,
        size: CGSize
    ) {
        let platform = SKShapeNode(
            rectOf: size,
            cornerRadius: 7
        )

        platform.fillColor = UIColor(
            red: 0.15,
            green: 0.17,
            blue: 0.21,
            alpha: 1
        )
        platform.strokeColor = UIColor(
            white: 0.42,
            alpha: 0.35
        )
        platform.lineWidth = 2
        platform.position = center
        platform.zPosition = 1

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0
        body.restitution = 0
        body.categoryBitMask = PhysicsCategory.world
        body.collisionBitMask = PhysicsCategory.player
        body.contactTestBitMask = 0

        platform.physicsBody = body

        addChild(platform)
        platforms.append(platform)
    }

    // MARK: - Player

    private func buildPlayer() {
        player.removeFromParent()
        player.removeAllChildren()
        playerVisual.removeAllChildren()

        player.fillColor = UIColor(
            red: 0.78,
            green: 0.82,
            blue: 0.9,
            alpha: 1
        )
        player.strokeColor = UIColor(
            white: 1,
            alpha: 0.22
        )
        player.lineWidth = 2
        player.zPosition = 50

        // Ground top is about 100. Start just above it.
        player.position = CGPoint(x: 230, y: 136)

        let body = SKPhysicsBody(
            rectangleOf: CGSize(width: 36, height: 60)
        )
        body.isDynamic = true
        body.affectedByGravity = true
        body.allowsRotation = false
        body.restitution = 0
        body.friction = 0
        body.linearDamping = 0
        body.angularDamping = 0

        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.world
        body.contactTestBitMask = 0

        body.usesPreciseCollisionDetection = true

        player.physicsBody = body

        let face = SKShapeNode(
            rectOf: CGSize(width: 20, height: 6),
            cornerRadius: 3
        )
        face.fillColor = UIColor(
            red: 0.48,
            green: 0.82,
            blue: 1,
            alpha: 1
        )
        face.strokeColor = .clear
        face.position = CGPoint(x: 5, y: 10)
        face.name = "face"
        playerVisual.addChild(face)

        let glow = SKShapeNode(
            ellipseOf: CGSize(width: 54, height: 14)
        )
        glow.fillColor = UIColor(
            red: 0.35,
            green: 0.7,
            blue: 1,
            alpha: 0.1
        )
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: -35)
        glow.zPosition = -1
        playerVisual.addChild(glow)

        player.addChild(playerVisual)
        addChild(player)
    }

    // MARK: - Camera

    private func buildCamera() {
        gameCamera.removeFromParent()
        addChild(gameCamera)
        camera = gameCamera

        gameCamera.setScale(cameraZoom)

        let halfVisibleWidth =
            size.width * 0.5 * cameraZoom

        let startX = max(
            halfVisibleWidth,
            player.position.x + 120
        )

        gameCamera.position = CGPoint(
            x: startX,
            y: size.height * 0.5 + cameraVerticalOffset
        )
    }

    // MARK: - HUD

    private func buildHUD() {
        hud.removeFromParent()
        hud.removeAllChildren()

        gameCamera.addChild(hud)
        hud.zPosition = 1000

        configureButton(leftButton)
        configureButton(rightButton)
        configureButton(jumpButton)

        leftArrow.text = "â¹"
        leftArrow.fontSize = 50
        leftArrow.fontColor = UIColor(white: 0.94, alpha: 0.9)
        leftArrow.verticalAlignmentMode = .center
        leftArrow.horizontalAlignmentMode = .center

        rightArrow.text = "âº"
        rightArrow.fontSize = 50
        rightArrow.fontColor = UIColor(white: 0.94, alpha: 0.9)
        rightArrow.verticalAlignmentMode = .center
        rightArrow.horizontalAlignmentMode = .center

        jumpLabel.text = "JUMP"
        jumpLabel.fontSize = 15
        jumpLabel.fontColor = UIColor(white: 0.94, alpha: 0.9)
        jumpLabel.verticalAlignmentMode = .center
        jumpLabel.horizontalAlignmentMode = .center

        buildLabel.text = "PHYSICS JUMP V5"
        buildLabel.fontSize = 12
        buildLabel.fontColor = UIColor(white: 1, alpha: 0.72)
        buildLabel.horizontalAlignmentMode = .center
        buildLabel.verticalAlignmentMode = .center

        leftButton.addChild(leftArrow)
        rightButton.addChild(rightArrow)
        jumpButton.addChild(jumpLabel)

        hud.addChild(leftButton)
        hud.addChild(rightButton)
        hud.addChild(jumpButton)
        hud.addChild(buildLabel)
    }

    private func configureButton(_ button: SKShapeNode) {
        button.fillColor = UIColor(white: 0.12, alpha: 0.62)
        button.strokeColor = UIColor(white: 1, alpha: 0.16)
        button.lineWidth = 2
    }

    private func layoutHUD() {
        guard size.width > 0, size.height > 0 else { return }

        let halfW = size.width * 0.5
        let halfH = size.height * 0.5
        let bottomPadding: CGFloat = max(72, size.height * 0.14)

        leftButton.position = CGPoint(
            x: -halfW + 82,
            y: -halfH + bottomPadding
        )

        rightButton.position = CGPoint(
            x: -halfW + 182,
            y: -halfH + bottomPadding
        )

        jumpButton.position = CGPoint(
            x: halfW - 92,
            y: -halfH + bottomPadding + 4
        )

        buildLabel.position = CGPoint(
            x: 0,
            y: halfH - 28
        )
    }

    // MARK: - Input

    override func touchesBegan(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let point = touch.location(in: hud)

            if isInside(point, button: leftButton, radius: 60) {
                leftTouches.insert(id)
                animateButton(leftButton, pressed: true)

            } else if isInside(point, button: rightButton, radius: 60) {
                rightTouches.insert(id)
                animateButton(rightButton, pressed: true)

            } else if isInside(point, button: jumpButton, radius: 120) {
                jumpTouches.insert(id)
                jumpHeld = true
                didCutJump = false

                jumpBufferTimer = jumpBufferDuration
                tryConsumeJump()

                animateButton(jumpButton, pressed: true)
            }
        }

        updateInputTarget()
    }

    override func touchesMoved(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let point = touch.location(in: hud)

            leftTouches.remove(id)
            rightTouches.remove(id)

            if isInside(point, button: leftButton, radius: 60) {
                leftTouches.insert(id)

            } else if isInside(point, button: rightButton, radius: 60) {
                rightTouches.insert(id)
            }
        }

        updateInputTarget()
        refreshButtonVisuals()
    }

    override func touchesEnded(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        releaseTouches(touches)
    }

    override func touchesCancelled(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        releaseTouches(touches)
    }

    private func releaseTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            let id = ObjectIdentifier(touch)

            leftTouches.remove(id)
            rightTouches.remove(id)

            if jumpTouches.remove(id) != nil,
               jumpTouches.isEmpty {
                jumpHeld = false
            }
        }

        updateInputTarget()
        refreshButtonVisuals()
    }

    private func isInside(
        _ point: CGPoint,
        button: SKShapeNode,
        radius: CGFloat
    ) -> Bool {
        hypot(
            point.x - button.position.x,
            point.y - button.position.y
        ) <= radius
    }

    private func updateInputTarget() {
        let left: CGFloat =
            leftTouches.isEmpty ? 0 : -1

        let right: CGFloat =
            rightTouches.isEmpty ? 0 : 1

        targetMoveInput = left + right
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        let dt: TimeInterval

        if lastUpdateTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(
                currentTime - lastUpdateTime,
                1.0 / 20.0
            )
        }

        lastUpdateTime = currentTime

        updateTimers(dt)
        updateHorizontal(CGFloat(dt))
        updateJump()
        updatePlayerVisuals(CGFloat(dt))
        updateCamera(CGFloat(dt))
    }

    override func didSimulatePhysics() {
        updateGroundedState()
    }

    private func updateTimers(_ dt: TimeInterval) {
        if isGrounded {
            coyoteTimer = coyoteDuration
        } else {
            coyoteTimer =
                max(0, coyoteTimer - dt)
        }

        jumpBufferTimer =
            max(0, jumpBufferTimer - dt)
    }

    private func updateHorizontal(_ dt: CGFloat) {
        guard let body = player.physicsBody else { return }

        let inputResponse: CGFloat = 12

        moveInput +=
            (targetMoveInput - moveInput) *
            min(1, inputResponse * dt)

        let targetVX = moveInput * runSpeed

        let accelerating =
            abs(targetMoveInput) > 0.01

        let acceleration: CGFloat

        if accelerating {
            acceleration =
                isGrounded
                ? groundAcceleration
                : airAcceleration
        } else {
            acceleration =
                isGrounded
                ? groundDeceleration
                : airAcceleration * 0.5
        }

        var vx = moveToward(
            body.velocity.dx,
            targetVX,
            maxDelta: acceleration * dt
        )

        if !accelerating && abs(vx) < 2 {
            vx = 0
        }

        let vy = max(
            body.velocity.dy,
            maxFallSpeed
        )

        // Horizontal code NEVER overwrites jump velocity.
        body.velocity = CGVector(
            dx: vx,
            dy: vy
        )

        if abs(targetMoveInput) > 0.01 {
            facing =
                targetMoveInput > 0 ? 1 : -1
        }
    }

    private func updateJump() {
        guard let body = player.physicsBody else { return }

        tryConsumeJump()

        if !jumpHeld &&
           !didCutJump &&
           body.velocity.dy > 120 {

            body.velocity = CGVector(
                dx: body.velocity.dx,
                dy: body.velocity.dy * 0.60
            )

            didCutJump = true
        }
    }

    private func tryConsumeJump() {
        guard let body = player.physicsBody else { return }
        guard jumpBufferTimer > 0 else { return }

        // Refresh the ground state at the exact moment JUMP is requested.
        // This avoids relying on a stale frame-based grounded flag.
        let standingOnSurface = isStandingOnSurface()

        let canJump =
            standingOnSurface ||
            isGrounded ||
            coyoteTimer > 0

        guard canJump else { return }

        // SpriteKit owns the player's position. We only change velocity.
        body.velocity = CGVector(
            dx: body.velocity.dx,
            dy: jumpVelocity
        )

        isGrounded = false
        coyoteTimer = 0
        jumpBufferTimer = 0
        didCutJump = false

        playJumpAnimation()
    }

    // MARK: - Ground detection

    private func isStandingOnSurface() -> Bool {
        guard let body = player.physicsBody else { return false }

        // Never become grounded while clearly moving upward.
        if body.velocity.dy > 45 {
            return false
        }

        // Probe a thin rectangle directly under the player's feet.
        // SKPhysicsWorld queries are in scene coordinates, so this does
        // not depend on SKShapeNode.frame or platform visual geometry.
        let halfWidth: CGFloat = 15
        let halfHeight: CGFloat = 30

        let feetY = player.position.y - halfHeight

        let probe = CGRect(
            x: player.position.x - halfWidth,
            y: feetY - 9,
            width: halfWidth * 2,
            height: 14
        )

        var foundWorld = false

        physicsWorld.enumerateBodies(in: probe) { physicsBody, stop in
            if physicsBody.categoryBitMask & PhysicsCategory.world != 0 {
                foundWorld = true
                stop.pointee = true
            }
        }

        return foundWorld
    }

    private func updateGroundedState() {
        let grounded = isStandingOnSurface()

        if grounded && !isGrounded {
            isGrounded = true
            coyoteTimer = coyoteDuration
            didCutJump = false
            playLandingAnimation()

        } else if grounded {
            isGrounded = true
            coyoteTimer = coyoteDuration

        } else {
            isGrounded = false
        }
    }

    // MARK: - Visuals

    private func updatePlayerVisuals(_ dt: CGFloat) {
        guard let body = player.physicsBody else { return }

        let speedRatio =
            min(abs(body.velocity.dx) / runSpeed, 1)

        let verticalRatio =
            max(
                -1,
                min(1, body.velocity.dy / jumpVelocity)
            )

        let targetRotation =
            -facing * speedRatio * 0.055

        playerVisual.zRotation +=
            (targetRotation - playerVisual.zRotation) *
            min(1, dt * 11)

        var targetScaleX: CGFloat = 1
        var targetScaleY: CGFloat = 1

        if !isGrounded {
            if verticalRatio > 0 {
                targetScaleX = 0.96
                targetScaleY = 1.045
            } else {
                targetScaleX = 1.035
                targetScaleY = 0.97
            }
        } else if speedRatio > 0.08 {
            let wave =
                sin(CGFloat(lastUpdateTime) * 11) *
                0.015 *
                speedRatio

            targetScaleX += wave
            targetScaleY -= wave
        }

        playerVisual.xScale +=
            (targetScaleX - playerVisual.xScale) *
            min(1, dt * 12)

        playerVisual.yScale +=
            (targetScaleY - playerVisual.yScale) *
            min(1, dt * 12)

        if let face =
            playerVisual.childNode(withName: "face") {

            let targetX: CGFloat =
                facing * 5

            face.position.x +=
                (targetX - face.position.x) *
                min(1, dt * 16)
        }
    }

    private func playJumpAnimation() {
        playerVisual.removeAction(forKey: "jump")

        let stretch = SKAction.scaleX(
            to: 0.93,
            y: 1.08,
            duration: 0.06
        )
        stretch.timingMode = .easeOut

        let settle = SKAction.scale(
            to: 1,
            duration: 0.11
        )
        settle.timingMode = .easeOut

        playerVisual.run(
            SKAction.sequence([stretch, settle]),
            withKey: "jump"
        )
    }

    private func playLandingAnimation() {
        playerVisual.removeAction(forKey: "land")

        let squash = SKAction.scaleX(
            to: 1.06,
            y: 0.93,
            duration: 0.05
        )
        squash.timingMode = .easeOut

        let settle = SKAction.scale(
            to: 1,
            duration: 0.10
        )
        settle.timingMode = .easeOut

        playerVisual.run(
            SKAction.sequence([squash, settle]),
            withKey: "land"
        )
    }

    // MARK: - Camera follow

    private func updateCamera(_ dt: CGFloat) {
        guard let body = player.physicsBody else { return }

        let visibleHalfWidth =
            size.width * 0.5 * cameraZoom

        let speedFactor =
            min(abs(body.velocity.dx) / runSpeed, 1)

        let direction: CGFloat

        if abs(body.velocity.dx) > 6 {
            direction =
                body.velocity.dx > 0 ? 1 : -1
        } else {
            direction = facing
        }

        let lookAhead =
            direction *
            cameraLookAhead *
            speedFactor

        let rawX =
            player.position.x + lookAhead

        let minX = visibleHalfWidth
        let maxX =
            max(
                minX,
                worldWidth - visibleHalfWidth
            )

        let targetX =
            max(minX, min(maxX, rawX))

        let follow =
            min(1, cameraFollowSpeed * dt)

        gameCamera.position.x +=
            (targetX - gameCamera.position.x) *
            follow

        let baseY =
            size.height * 0.5 +
            cameraVerticalOffset

        let relativeY =
            player.position.y - 150

        let desiredY =
            baseY +
            max(
                -30,
                min(55, relativeY * 0.16)
            )

        gameCamera.position.y +=
            (desiredY - gameCamera.position.y) *
            min(1, 2.4 * dt)
    }

    // MARK: - Button visuals

    private func refreshButtonVisuals() {
        animateButton(
            leftButton,
            pressed: !leftTouches.isEmpty
        )

        animateButton(
            rightButton,
            pressed: !rightTouches.isEmpty
        )

        animateButton(
            jumpButton,
            pressed: !jumpTouches.isEmpty
        )
    }

    private func animateButton(
        _ button: SKShapeNode,
        pressed: Bool
    ) {
        button.removeAction(forKey: "press")

        let scale: CGFloat =
            pressed ? 0.9 : 1

        let alpha: CGFloat =
            pressed ? 0.82 : 1

        let action = SKAction.group([
            SKAction.scale(
                to: scale,
                duration: 0.08
            ),
            SKAction.fadeAlpha(
                to: alpha,
                duration: 0.08
            )
        ])

        action.timingMode = .easeOut

        button.run(
            action,
            withKey: "press"
        )
    }

    // MARK: - Helpers

    private func moveToward(
        _ current: CGFloat,
        _ target: CGFloat,
        maxDelta: CGFloat
    ) -> CGFloat {
        if abs(target - current) <= maxDelta {
            return target
        }

        return current +
            (target > current
             ? maxDelta
             : -maxDelta)
    }
}
