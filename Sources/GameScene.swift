import SpriteKit
import UIKit

final class GameScene: SKScene {

    // MARK: - World

    private let world = SKNode()
    private let gameCamera = SKCameraNode()
    private var platforms: [SKShapeNode] = []
    private var worldWidth: CGFloat = 2200

    // MARK: - Player

    private let player = SKShapeNode(
        rectOf: CGSize(width: 42, height: 64),
        cornerRadius: 10
    )
    private let playerVisual = SKNode()

    private let playerHalfWidth: CGFloat = 18
    private let playerHalfHeight: CGFloat = 30

    private var velocity = CGVector.zero
    private var moveInput: CGFloat = 0
    private var targetMoveInput: CGFloat = 0
    private var facing: CGFloat = 1

    private let runSpeed: CGFloat = 315
    private let groundAcceleration: CGFloat = 1800
    private let airAcceleration: CGFloat = 1050
    private let groundDeceleration: CGFloat = 2200

    private let gravity: CGFloat = -1700
    private let jumpVelocity: CGFloat = 610
    private let maxFallSpeed: CGFloat = -900

    private var isGrounded = false
    private var wasGrounded = false

    private let coyoteDuration: TimeInterval = 0.11
    private var coyoteTimer: TimeInterval = 0

    private let jumpBufferDuration: TimeInterval = 0.12
    private var jumpBufferTimer: TimeInterval = 0

    private var jumpHeld = false
    private var didCutJump = false

    // MARK: - Timing

    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Camera

    private let cameraZoom: CGFloat = 1.62
    private let cameraFollowSpeed: CGFloat = 3.6
    private let cameraLookAhead: CGFloat = 135
    private let cameraVerticalOffset: CGFloat = 28

    // MARK: - HUD

    private let hud = SKNode()

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
        view.shouldCullNonVisibleNodes = true
        view.isMultipleTouchEnabled = true

        // IMPORTANT:
        // Stage 2 uses deterministic kinematic movement.
        // SpriteKit physics is intentionally NOT used for the player.
        // This prevents the physics solver from fighting our jump code.
        physicsWorld.gravity = .zero

        addChild(world)
        addChild(gameCamera)
        camera = gameCamera

        buildWorld()
        buildPlayer()
        buildHUD()
        layoutScene()

        gameCamera.setScale(cameraZoom)
        gameCamera.position = CGPoint(
            x: max(size.width * 0.5 * cameraZoom, player.position.x),
            y: size.height * 0.5 + cameraVerticalOffset
        )
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutScene()
    }

    // MARK: - World

    private func buildWorld() {
        world.removeAllChildren()
        platforms.removeAll()

        worldWidth = max(2200, size.width * 3.0)

        let backdrop = SKShapeNode(
            rectOf: CGSize(width: worldWidth, height: max(size.height, 430))
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
            y: max(size.height, 430) * 0.5
        )
        backdrop.zPosition = -50
        world.addChild(backdrop)

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
            pillar.zPosition = -30
            world.addChild(pillar)
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

    private func addPlatform(center: CGPoint, size: CGSize) {
        let platform = SKShapeNode(rectOf: size, cornerRadius: 7)
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

        // No SKPhysicsBody here. Collision is resolved deterministically below.
        world.addChild(platform)
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
            alpha: 0.18
        )
        player.lineWidth = 2
        player.zPosition = 20

        // Ground top is y = 100, so center y = 130 places our 60pt collider exactly on it.
        player.position = CGPoint(x: 170, y: 130)
        velocity = .zero
        isGrounded = true
        wasGrounded = true
        coyoteTimer = coyoteDuration

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
        world.addChild(player)
    }

    // MARK: - HUD

    private func buildHUD() {
        hud.removeFromParent()
        hud.removeAllChildren()

        gameCamera.addChild(hud)
        hud.zPosition = 1000

        configureControlButton(leftButton)
        configureControlButton(rightButton)
        configureControlButton(jumpButton)

        leftArrow.text = "‹"
        leftArrow.fontSize = 50
        leftArrow.verticalAlignmentMode = .center
        leftArrow.horizontalAlignmentMode = .center

        rightArrow.text = "›"
        rightArrow.fontSize = 50
        rightArrow.verticalAlignmentMode = .center
        rightArrow.horizontalAlignmentMode = .center

        jumpLabel.text = "JUMP"
        jumpLabel.fontSize = 15
        jumpLabel.verticalAlignmentMode = .center
        jumpLabel.horizontalAlignmentMode = .center

        buildLabel.text = "KINEMATIC JUMP V3"
        buildLabel.fontSize = 12
        buildLabel.fontColor = UIColor(white: 1, alpha: 0.72)
        buildLabel.horizontalAlignmentMode = .center
        buildLabel.verticalAlignmentMode = .center

        [leftArrow, rightArrow, jumpLabel].forEach {
            $0.fontColor = UIColor(white: 0.94, alpha: 0.88)
        }

        leftButton.addChild(leftArrow)
        rightButton.addChild(rightArrow)
        jumpButton.addChild(jumpLabel)

        hud.addChild(leftButton)
        hud.addChild(rightButton)
        hud.addChild(jumpButton)
        hud.addChild(buildLabel)
    }

    private func configureControlButton(_ button: SKShapeNode) {
        button.fillColor = UIColor(white: 0.12, alpha: 0.62)
        button.strokeColor = UIColor(white: 1, alpha: 0.16)
        button.lineWidth = 2
    }

    private func layoutScene() {
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

        gameCamera.setScale(cameraZoom)
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let point = touch.location(in: hud)

            if isInside(point, button: leftButton, radius: 58) {
                leftTouches.insert(id)
                animateButton(leftButton, pressed: true)
            } else if isInside(point, button: rightButton, radius: 58) {
                rightTouches.insert(id)
                animateButton(rightButton, pressed: true)
            } else if isInside(point, button: jumpButton, radius: 82) {
                jumpTouches.insert(id)
                jumpHeld = true
                jumpBufferTimer = jumpBufferDuration
                didCutJump = false
                tryConsumeJump()
                animateButton(jumpButton, pressed: true)
            }
        }

        updateInputTarget()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let point = touch.location(in: hud)

            leftTouches.remove(id)
            rightTouches.remove(id)

            if isInside(point, button: leftButton, radius: 58) {
                leftTouches.insert(id)
            } else if isInside(point, button: rightButton, radius: 58) {
                rightTouches.insert(id)
            }
        }

        refreshButtonVisuals()
        updateInputTarget()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseTouches(touches)
    }

    private func releaseTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            let id = ObjectIdentifier(touch)

            leftTouches.remove(id)
            rightTouches.remove(id)

            if jumpTouches.remove(id) != nil, jumpTouches.isEmpty {
                jumpHeld = false
            }
        }

        refreshButtonVisuals()
        updateInputTarget()
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
        let left: CGFloat = leftTouches.isEmpty ? 0 : -1
        let right: CGFloat = rightTouches.isEmpty ? 0 : 1
        targetMoveInput = left + right
    }

    private func refreshButtonVisuals() {
        animateButton(leftButton, pressed: !leftTouches.isEmpty)
        animateButton(rightButton, pressed: !rightTouches.isEmpty)
        animateButton(jumpButton, pressed: !jumpTouches.isEmpty)
    }

    private func animateButton(_ button: SKShapeNode, pressed: Bool) {
        button.removeAction(forKey: "press")

        let scale: CGFloat = pressed ? 0.9 : 1
        let alpha: CGFloat = pressed ? 0.82 : 1

        let action = SKAction.group([
            SKAction.scale(to: scale, duration: 0.08),
            SKAction.fadeAlpha(to: alpha, duration: 0.08)
        ])
        action.timingMode = .easeOut

        button.run(action, withKey: "press")
    }

    // MARK: - Game loop

    override func update(_ currentTime: TimeInterval) {
        let dt: TimeInterval

        if lastUpdateTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(currentTime - lastUpdateTime, 1.0 / 20.0)
        }

        lastUpdateTime = currentTime

        updateTimers(dt)
        updateHorizontal(CGFloat(dt))
        updateVertical(CGFloat(dt))
        resolveMovement(CGFloat(dt))
        updatePlayerVisuals(CGFloat(dt))
        updateCamera(CGFloat(dt))
    }

    private func updateTimers(_ dt: TimeInterval) {
        if isGrounded {
            coyoteTimer = coyoteDuration
        } else {
            coyoteTimer = max(0, coyoteTimer - dt)
        }

        jumpBufferTimer = max(0, jumpBufferTimer - dt)
    }

    private func updateHorizontal(_ dt: CGFloat) {
        let inputResponse: CGFloat = 12

        moveInput +=
            (targetMoveInput - moveInput) * min(1, inputResponse * dt)

        let targetVX = moveInput * runSpeed
        let accelerating = abs(targetMoveInput) > 0.01

        let acceleration: CGFloat
        if accelerating {
            acceleration = isGrounded ? groundAcceleration : airAcceleration
        } else {
            acceleration = isGrounded ? groundDeceleration : airAcceleration * 0.5
        }

        velocity.dx = moveToward(
            velocity.dx,
            targetVX,
            maxDelta: acceleration * dt
        )

        if !accelerating && abs(velocity.dx) < 2 {
            velocity.dx = 0
        }

        if abs(targetMoveInput) > 0.01 {
            facing = targetMoveInput > 0 ? 1 : -1
        }
    }

    private func updateVertical(_ dt: CGFloat) {
        tryConsumeJump()

        if !isGrounded {
            velocity.dy = max(
                maxFallSpeed,
                velocity.dy + gravity * dt
            )
        } else if velocity.dy < 0 {
            velocity.dy = 0
        }

        // Variable jump height.
        if !jumpHeld && !didCutJump && velocity.dy > 110 {
            velocity.dy *= 0.62
            didCutJump = true
        }
    }

    private func tryConsumeJump() {
        guard jumpBufferTimer > 0 else { return }
        guard isGrounded || coyoteTimer > 0 else { return }

        velocity.dy = jumpVelocity
        isGrounded = false
        coyoteTimer = 0
        jumpBufferTimer = 0
        didCutJump = false

        // Lift 1 point so the next collision pass cannot consider us still standing.
        player.position.y += 1
        squashAndStretchForJump()
    }

    // MARK: - Deterministic collision

    private func resolveMovement(_ dt: CGFloat) {
        wasGrounded = isGrounded
        isGrounded = false

        let oldPosition = player.position

        // Horizontal move first.
        var nextX = oldPosition.x + velocity.dx * dt
        nextX = max(playerHalfWidth, min(worldWidth - playerHalfWidth, nextX))

        var horizontalPosition = CGPoint(
            x: nextX,
            y: oldPosition.y
        )

        // Prevent entering solid platform sides.
        for platform in platforms {
            let rect = platform.frame

            let playerMinY = horizontalPosition.y - playerHalfHeight
            let playerMaxY = horizontalPosition.y + playerHalfHeight
            let overlapsY =
                playerMaxY > rect.minY + 2 &&
                playerMinY < rect.maxY - 2

            guard overlapsY else { continue }

            if velocity.dx > 0 {
                let oldRight = oldPosition.x + playerHalfWidth
                let newRight = horizontalPosition.x + playerHalfWidth

                if oldRight <= rect.minX && newRight > rect.minX {
                    horizontalPosition.x = rect.minX - playerHalfWidth
                    velocity.dx = 0
                }
            } else if velocity.dx < 0 {
                let oldLeft = oldPosition.x - playerHalfWidth
                let newLeft = horizontalPosition.x - playerHalfWidth

                if oldLeft >= rect.maxX && newLeft < rect.maxX {
                    horizontalPosition.x = rect.maxX + playerHalfWidth
                    velocity.dx = 0
                }
            }
        }

        // Vertical move second.
        let verticalStart = horizontalPosition
        var verticalPosition = CGPoint(
            x: horizontalPosition.x,
            y: horizontalPosition.y + velocity.dy * dt
        )

        for platform in platforms {
            let rect = platform.frame

            let playerLeft = verticalPosition.x - playerHalfWidth
            let playerRight = verticalPosition.x + playerHalfWidth
            let overlapsX =
                playerRight > rect.minX + 2 &&
                playerLeft < rect.maxX - 2

            guard overlapsX else { continue }

            if velocity.dy <= 0 {
                let oldBottom = verticalStart.y - playerHalfHeight
                let newBottom = verticalPosition.y - playerHalfHeight

                // Crossed platform top while falling.
                if oldBottom >= rect.maxY - 1 && newBottom <= rect.maxY {
                    verticalPosition.y = rect.maxY + playerHalfHeight
                    velocity.dy = 0
                    isGrounded = true
                }
            } else {
                let oldTop = verticalStart.y + playerHalfHeight
                let newTop = verticalPosition.y + playerHalfHeight

                // Hit underside while rising.
                if oldTop <= rect.minY + 1 && newTop >= rect.minY {
                    verticalPosition.y = rect.minY - playerHalfHeight
                    velocity.dy = 0
                }
            }
        }

        player.position = verticalPosition

        // Safety snap to the floor after tiny numerical gaps.
        if !isGrounded && velocity.dy <= 0 {
            for platform in platforms {
                let rect = platform.frame
                let left = player.position.x - playerHalfWidth
                let right = player.position.x + playerHalfWidth
                let bottom = player.position.y - playerHalfHeight

                let overlapsX =
                    right > rect.minX + 2 &&
                    left < rect.maxX - 2

                if overlapsX &&
                    bottom >= rect.maxY &&
                    bottom - rect.maxY <= 2.5 {
                    player.position.y = rect.maxY + playerHalfHeight
                    velocity.dy = 0
                    isGrounded = true
                    break
                }
            }
        }

        if isGrounded && !wasGrounded {
            didCutJump = false
            landingAnimation()
        }
    }

    // MARK: - Visuals

    private func updatePlayerVisuals(_ dt: CGFloat) {
        let speedRatio = min(abs(velocity.dx) / runSpeed, 1)
        let verticalRatio = max(-1, min(1, velocity.dy / jumpVelocity))

        let targetRotation =
            -facing * speedRatio * 0.055

        playerVisual.zRotation +=
            (targetRotation - playerVisual.zRotation) * min(1, dt * 11)

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
                sin(CGFloat(lastUpdateTime) * 11) * 0.015 * speedRatio
            targetScaleX += wave
            targetScaleY -= wave
        }

        playerVisual.xScale +=
            (targetScaleX - playerVisual.xScale) * min(1, dt * 12)

        playerVisual.yScale +=
            (targetScaleY - playerVisual.yScale) * min(1, dt * 12)

        if let face = playerVisual.childNode(withName: "face") {
            let targetX: CGFloat = facing * 5
            face.position.x +=
                (targetX - face.position.x) * min(1, dt * 16)
        }
    }

    private func squashAndStretchForJump() {
        playerVisual.removeAction(forKey: "jumpStretch")

        let stretch = SKAction.scaleX(
            to: 0.93,
            y: 1.08,
            duration: 0.07
        )
        stretch.timingMode = .easeOut

        let settle = SKAction.scale(
            to: 1,
            duration: 0.12
        )
        settle.timingMode = .easeOut

        playerVisual.run(
            SKAction.sequence([stretch, settle]),
            withKey: "jumpStretch"
        )
    }

    private func landingAnimation() {
        playerVisual.removeAction(forKey: "land")

        let squash = SKAction.scaleX(
            to: 1.07,
            y: 0.92,
            duration: 0.055
        )
        squash.timingMode = .easeOut

        let settle = SKAction.scale(
            to: 1,
            duration: 0.11
        )
        settle.timingMode = .easeOut

        playerVisual.run(
            SKAction.sequence([squash, settle]),
            withKey: "land"
        )
    }

    // MARK: - Camera

    private func updateCamera(_ dt: CGFloat) {
        let visibleHalfWidth =
            size.width * 0.5 * cameraZoom

        let speedFactor =
            min(abs(velocity.dx) / runSpeed, 1)

        let direction: CGFloat
        if abs(velocity.dx) > 6 {
            direction = velocity.dx > 0 ? 1 : -1
        } else {
            direction = facing
        }

        let desiredLookAhead =
            direction * cameraLookAhead * speedFactor

        let targetXRaw =
            player.position.x + desiredLookAhead

        let minCameraX = visibleHalfWidth
        let maxCameraX =
            max(minCameraX, worldWidth - visibleHalfWidth)

        let targetX =
            max(minCameraX, min(maxCameraX, targetXRaw))

        let follow = min(1, cameraFollowSpeed * dt)

        gameCamera.position.x +=
            (targetX - gameCamera.position.x) * follow

        let baseY =
            size.height * 0.5 + cameraVerticalOffset

        let playerRelativeY =
            player.position.y - 150

        let desiredY =
            baseY + max(-30, min(55, playerRelativeY * 0.18))

        gameCamera.position.y +=
            (desiredY - gameCamera.position.y) * min(1, 2.2 * dt)
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

        return current + (target > current ? maxDelta : -maxDelta)
    }
}
