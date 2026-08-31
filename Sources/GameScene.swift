import SpriteKit
import UIKit

final class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Physics masks

    private enum PhysicsCategory {
        static let none: UInt32   = 0
        static let player: UInt32 = 1 << 0
        static let ground: UInt32 = 1 << 1
    }

    // MARK: - Player

    private let player = SKShapeNode(
        rectOf: CGSize(width: 42, height: 64),
        cornerRadius: 10
    )

    private let playerVisual = SKNode()

    private var moveInput: CGFloat = 0
    private var targetMoveInput: CGFloat = 0
    private var facing: CGFloat = 1

    private let runSpeed: CGFloat = 315
    private let groundAcceleration: CGFloat = 1800
    private let airAcceleration: CGFloat = 1050
    private let groundDeceleration: CGFloat = 2200
    private let jumpVelocity: CGFloat = 610
    private let maxFallSpeed: CGFloat = -900

    private var isGrounded = false
    private var groundContacts = 0

    // Gives a small grace period after stepping off a ledge.
    private let coyoteDuration: TimeInterval = 0.11
    private var coyoteTimer: TimeInterval = 0

    // Remembers a jump press just before touching the ground.
    private let jumpBufferDuration: TimeInterval = 0.12
    private var jumpBufferTimer: TimeInterval = 0

    private var jumpHeld = false
    private var didCutJump = false

    // MARK: - Timing

    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Camera / world

    private let world = SKNode()
    private let gameCamera = SKCameraNode()
    private var worldWidth: CGFloat = 1800
    private var platforms: [SKShapeNode] = []

    // Wider, more platformer-like framing: the player occupies less of the screen
    // and the camera shows more space ahead and above/below.
    private let cameraZoom: CGFloat = 1.62
    private let cameraFollowSpeed: CGFloat = 3.6
    private let cameraLookAhead: CGFloat = 135
    private let cameraVerticalOffset: CGFloat = 28

    // MARK: - HUD controls

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

        physicsWorld.gravity = CGVector(dx: 0, dy: -1700)
        physicsWorld.contactDelegate = self

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

        worldWidth = max(1800, size.width * 2.5)

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

        // Very subtle background shapes so movement is easier to read.
        for index in 0..<10 {
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

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.friction = 0.2
        body.restitution = 0
        body.categoryBitMask = PhysicsCategory.ground
        body.collisionBitMask = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.player
        platform.physicsBody = body

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
        player.position = CGPoint(x: 170, y: 150)

        let body = SKPhysicsBody(
            rectangleOf: CGSize(width: 36, height: 60),
            center: CGPoint(x: 0, y: 0)
        )
        body.allowsRotation = false
        body.restitution = 0
        body.friction = 0
        body.linearDamping = 0
        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.ground
        body.contactTestBitMask = PhysicsCategory.ground
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

        buildLabel.text = "CAM/JUMP FIX"
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

        // Keep the gameplay framing wide and slightly above the character.
        gameCamera.setScale(cameraZoom)
        gameCamera.position.y = max(
            size.height * 0.5 + cameraVerticalOffset,
            210
        )
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let point = touch.location(in: hud)

            if leftButton.contains(point) {
                leftTouches.insert(id)
                animateButton(leftButton, pressed: true)
            } else if rightButton.contains(point) {
                rightTouches.insert(id)
                animateButton(rightButton, pressed: true)
            } else if jumpButton.contains(point) {
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

            if leftButton.contains(point) {
                leftTouches.insert(id)
            } else if rightButton.contains(point) {
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

    private func updateInputTarget() {
        let left = leftTouches.isEmpty ? CGFloat(0) : CGFloat(-1)
        let right = rightTouches.isEmpty ? CGFloat(0) : CGFloat(1)
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

        updateGroundedState()
        updateTimers(dt)
        updateMovement(CGFloat(dt))
        updateJump()
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

    private func updateMovement(_ dt: CGFloat) {
        guard let body = player.physicsBody else { return }

        // Smooth the input itself, not only the velocity.
        let inputResponse: CGFloat = 12
        moveInput += (targetMoveInput - moveInput) * min(1, inputResponse * dt)

        var vx = body.velocity.dx
        let targetVX = moveInput * runSpeed

        let accelerating = abs(targetMoveInput) > 0.01
        let accel: CGFloat

        if accelerating {
            accel = isGrounded ? groundAcceleration : airAcceleration
        } else {
            accel = isGrounded ? groundDeceleration : airAcceleration * 0.5
        }

        vx = moveToward(vx, targetVX, maxDelta: accel * dt)

        // Snap only when extremely close to zero to avoid endless micro sliding.
        if !accelerating && abs(vx) < 2 {
            vx = 0
        }

        let vy = max(body.velocity.dy, maxFallSpeed)
        body.velocity = CGVector(dx: vx, dy: vy)

        if abs(targetMoveInput) > 0.01 {
            facing = targetMoveInput > 0 ? 1 : -1
        }
    }

    private func updateJump() {
        guard let body = player.physicsBody else { return }

        tryConsumeJump()

        // Variable jump height: releasing jump early gives a shorter jump.
        if !jumpHeld && !didCutJump && body.velocity.dy > 110 {
            body.velocity.dy *= 0.56
            didCutJump = true
        }
    }

    private func tryConsumeJump() {
        guard let body = player.physicsBody else { return }

        let canJump = isGrounded || coyoteTimer > 0 || isPlayerCloseToPlatformTop()

        if jumpBufferTimer > 0 && canJump {
            body.velocity = CGVector(dx: body.velocity.dx, dy: jumpVelocity)
            jumpBufferTimer = 0
            coyoteTimer = 0
            isGrounded = false
            groundContacts = 0
            didCutJump = false
            squashAndStretchForJump()
        }
    }

    private func isPlayerCloseToPlatformTop() -> Bool {
        let halfWidth: CGFloat = 18
        let halfHeight: CGFloat = 30
        let left = player.position.x - halfWidth
        let right = player.position.x + halfWidth
        let bottom = player.position.y - halfHeight

        for platform in platforms {
            let frame = platform.frame
            let overlapsX = right > frame.minX + 2 && left < frame.maxX - 2
            let nearTop = bottom >= frame.maxY - 14 && bottom <= frame.maxY + 14

            if overlapsX && nearTop {
                return true
            }
        }

        return false
    }

    // Ground detection is deliberately geometric instead of relying only on
    // SpriteKit contact callbacks. This avoids a common case where the player
    // is visibly standing on a platform but the jump state never becomes true.
    private func updateGroundedState() {
        guard let body = player.physicsBody else { return }

        let halfWidth: CGFloat = 18
        let halfHeight: CGFloat = 30
        let playerLeft = player.position.x - halfWidth
        let playerRight = player.position.x + halfWidth
        let playerBottom = player.position.y - halfHeight
        let verticalVelocity = body.velocity.dy

        var standing = false

        if verticalVelocity <= 45 {
            for platform in platforms {
                let frame = platform.frame
                let horizontalOverlap =
                    playerRight > frame.minX + 2 &&
                    playerLeft < frame.maxX - 2

                let distanceToTop = abs(playerBottom - frame.maxY)

                if horizontalOverlap && distanceToTop <= 9 {
                    standing = true
                    break
                }
            }
        }

        if standing && !isGrounded {
            isGrounded = true
            groundContacts = 1
            didCutJump = false
            landingAnimation()
        } else if !standing && isGrounded && verticalVelocity > 55 {
            isGrounded = false
            groundContacts = 0
        } else if !standing && verticalVelocity < -80 {
            isGrounded = false
            groundContacts = 0
        }
    }

    private func updatePlayerVisuals(_ dt: CGFloat) {
        guard let body = player.physicsBody else { return }

        let speedRatio = min(abs(body.velocity.dx) / runSpeed, 1)
        let verticalRatio = max(-1, min(1, body.velocity.dy / jumpVelocity))

        // Smooth body lean.
        let targetRotation = -facing * speedRatio * 0.055
        playerVisual.zRotation +=
            (targetRotation - playerVisual.zRotation) * min(1, dt * 11)

        // Smooth squash/stretch that reacts to vertical motion.
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
            // Tiny breathing/running motion. Kept subtle until sprites arrive.
            let wave = sin(CGFloat(lastUpdateTime) * 11) * 0.015 * speedRatio
            targetScaleX += wave
            targetScaleY -= wave
        }

        playerVisual.xScale +=
            (targetScaleX - playerVisual.xScale) * min(1, dt * 12)
        playerVisual.yScale +=
            (targetScaleY - playerVisual.yScale) * min(1, dt * 12)

        // Face turns smoothly with the character.
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

    // MARK: - Camera

    private func updateCamera(_ dt: CGFloat) {
        let visibleHalfWidth = size.width * 0.5 * cameraZoom

        let vx = player.physicsBody?.velocity.dx ?? 0
        let speedFactor = min(abs(vx) / runSpeed, 1)
        let direction: CGFloat

        if abs(vx) > 6 {
            direction = vx > 0 ? 1 : -1
        } else {
            direction = facing
        }

        // Show more of the space the player is moving toward, but ease into it.
        let desiredLookAhead = direction * cameraLookAhead * speedFactor
        let targetXRaw = player.position.x + desiredLookAhead

        var targetX = targetXRaw
        targetX = max(visibleHalfWidth, targetX)
        targetX = min(worldWidth - visibleHalfWidth, targetX)

        let follow = min(1, cameraFollowSpeed * dt)
        gameCamera.position.x +=
            (targetX - gameCamera.position.x) * follow

        // Very soft vertical follow. It does not chase every jump, which keeps
        // platforming readable and avoids a nervous camera.
        let baseY = size.height * 0.5 + cameraVerticalOffset
        let playerRelativeY = player.position.y - 150
        let desiredY = baseY + max(-30, min(55, playerRelativeY * 0.18))
        gameCamera.position.y +=
            (desiredY - gameCamera.position.y) * min(1, 2.2 * dt)
    }

    // MARK: - Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        if isPlayerGroundContact(contact) {
            groundContacts += 1
        }
    }

    func didEnd(_ contact: SKPhysicsContact) {
        if isPlayerGroundContact(contact) {
            groundContacts = max(0, groundContacts - 1)
        }
    }

    private func isPlayerGroundContact(_ contact: SKPhysicsContact) -> Bool {
        let categories =
            contact.bodyA.categoryBitMask |
            contact.bodyB.categoryBitMask

        return categories ==
            (PhysicsCategory.player | PhysicsCategory.ground)
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
