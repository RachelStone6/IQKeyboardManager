

import UIKit

// MARK: - Enums
public enum FloatingDirection {
    case left, right, top, bottom
}

public enum FloatingLayoutDirection {
    case clockwise, counterClockwise
}

public enum FloatingAlignment {
    case left, right, top, bottom, center
}

// MARK: - Protocols
public protocol FloatingButtonDelegate: AnyObject {
    func floatingButtonDidOpen()
    func floatingButtonDidClose()
    func floatingButtonDidTapSubmenu(at index: Int)
}

// MARK: - FloatingButton UIKit Implementation
public class FloatingButton: UIView {
    
    // MARK: - Public Properties
    public weak var delegate: FloatingButtonDelegate?
    
    // MARK: - Private Properties
    private var mainButton: UIButton!
    private var submenuButtons: [UIButton] = []
    private var buttonFrames: [CGRect] = []
    private var isOpen: Bool = false
    
    // Drag functionality
    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var initialDragPosition: CGPoint = .zero
    private var isDragging: Bool = false
    private var dragThreshold: CGFloat = 10 // Minimum distance to start dragging
    
    // Configuration
    private var direction: FloatingDirection = .left
    private var alignment: FloatingAlignment = .center
    private var spacing: CGFloat = 10
    private var initialScaling: CGFloat = 0.3
    private var initialOpacity: CGFloat = 0.0
    private var animationDuration: TimeInterval = 0.4
    private var buttonSize: CGFloat = 50
    private var submenuButtonSize: CGFloat = 40
    
    // Drag configuration
    private var isDragEnabled: Bool = true
    private var snapToEdgeEnabled: Bool = true
    private var safeMargin: CGFloat = 30
    
    // Circle layout properties
    private var isCircleLayout: Bool = false
    private var layoutDirection: FloatingLayoutDirection = .clockwise
    private var startAngle: Double = .pi
    private var endAngle: Double = 2 * .pi
    private var radius: Double = 100
    
    // MARK: - Initialization
    public init(mainButtonImage: UIImage?, submenuImages: [UIImage]) {
        super.init(frame: .zero)
        setupMainButton(image: mainButtonImage)
        setupSubmenuButtons(images: submenuImages)
        setupInitialLayout()
        setupDragGesture()
    }
    
    public init(mainButtonSystemName: String, submenuSystemNames: [String]) {
        super.init(frame: .zero)
        self.isUserInteractionEnabled = true
        let mainImage = UIImage(systemName: mainButtonSystemName)
        let submenuImages = submenuSystemNames.compactMap { UIImage(systemName: $0) }
        setupMainButton(image: mainImage)
        setupSubmenuButtons(images: submenuImages)
        setupInitialLayout()
        setupDragGesture()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupMainButton(image: UIImage?) {
        mainButton = UIButton(type: .custom)
        mainButton.setImage(image, for: .normal)
        mainButton.backgroundColor = UIColor.systemBlue
        mainButton.tintColor = .white
        mainButton.layer.cornerRadius = buttonSize / 2
        mainButton.layer.shadowColor = UIColor.black.cgColor
        mainButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        mainButton.layer.shadowRadius = 4
        mainButton.layer.shadowOpacity = 0.3
        mainButton.addTarget(self, action: #selector(mainButtonTapped), for: .touchUpInside)
        addSubview(mainButton)
        mainButton.alpha = 0.6
    }
    
    private func setupSubmenuButtons(images: [UIImage]) {
        submenuButtons.removeAll()
        
        for (index, image) in images.enumerated() {
            let button = UIButton(type: .custom)
            button.setImage(image, for: .normal)
            button.backgroundColor = UIColor.systemGray
            button.tintColor = .white
            button.layer.cornerRadius = submenuButtonSize / 2
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 2)
            button.layer.shadowRadius = 4
            button.layer.shadowOpacity = 0.3
            button.tag = index
            button.alpha = initialOpacity
            button.transform = CGAffineTransform(scaleX: initialScaling, y: initialScaling)
            button.addTarget(self, action: #selector(submenuButtonTapped(_:)), for: .touchUpInside)
            
            submenuButtons.append(button)
            addSubview(button)
        }
    }
    
    private func setupInitialLayout() {
        backgroundColor = UIColor.clear
        calculateButtonFrames()
    }
    
    private func setupDragGesture() {
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGestureRecognizer.delegate = self
        mainButton.addGestureRecognizer(panGestureRecognizer)
    }
    
    // MARK: - Layout Methods
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // Position main button at center
        let mainButtonFrame = CGRect(
            x: (bounds.width - buttonSize) / 2,
            y: (bounds.height - buttonSize) / 2,
            width: buttonSize,
            height: buttonSize
        )
        mainButton.frame = mainButtonFrame
        
        // Ensure corner radius is correct after frame changes
        updateMainButtonCornerRadius()
        
        calculateButtonFrames()
        layoutSubmenuButtons()
    }
    
    // MARK: - Hit Testing Override
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Only allow hit testing if the FloatingButton itself allows user interaction
        guard isUserInteractionEnabled else {
            return super.hitTest(point, with: event)
        }
        
        // Check if point is within main button
        if mainButton.isUserInteractionEnabled && mainButton.frame.contains(point) {
            // Convert point to main button's coordinate system
            let mainButtonPoint = convert(point, to: mainButton)
            if mainButton.point(inside: mainButtonPoint, with: event) {
                return mainButton
            }
        }
        
        // Check submenu buttons only if menu is open
        if isOpen {
            for submenuButton in submenuButtons {
                if submenuButton.isUserInteractionEnabled && 
                   submenuButton.alpha > 0.01 && // Only check visible buttons
                   submenuButton.frame.contains(point) {
                    // Convert point to submenu button's coordinate system
                    let submenuButtonPoint = convert(point, to: submenuButton)
                    if submenuButton.point(inside: submenuButtonPoint, with: event) {
                        return submenuButton
                    }
                }
            }
        }
        
        // If point is not within any button, return nil to pass through to underlying views
        return nil
    }
    
    private func calculateButtonFrames() {
        guard !submenuButtons.isEmpty else { return }
        
        buttonFrames.removeAll()
        
        if isCircleLayout {
            calculateCircleLayout()
        } else {
            calculateStraightLayout()
        }
    }
    
    private func calculateStraightLayout() {
        let mainCenter = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        var currentPosition = mainCenter
        
        for i in 0..<submenuButtons.count {
            let buttonSpacing = (buttonSize + submenuButtonSize) / 2 + spacing
            
            switch direction {
            case .left:
                currentPosition.x -= buttonSpacing
            case .right:
                currentPosition.x += buttonSpacing
            case .top:
                currentPosition.y -= buttonSpacing
            case .bottom:
                currentPosition.y += buttonSpacing
            }
            
            let frame = CGRect(
                x: currentPosition.x - submenuButtonSize / 2,
                y: currentPosition.y - submenuButtonSize / 2,
                width: submenuButtonSize,
                height: submenuButtonSize
            )
            
            buttonFrames.append(frame)
        }
    }
    
    private func calculateCircleLayout() {
        let mainCenter = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let count = submenuButtons.count
        
        for i in 0..<count {
            let increment = (endAngle - startAngle) / Double(count - 1) * Double(i)
            let angle = layoutDirection == .clockwise ? startAngle + increment : startAngle - increment
            
            let x = mainCenter.x + CGFloat(radius * cos(angle))
            let y = mainCenter.y + CGFloat(radius * sin(angle))
            
            let frame = CGRect(
                x: x - submenuButtonSize / 2,
                y: y - submenuButtonSize / 2,
                width: submenuButtonSize,
                height: submenuButtonSize
            )
            
            buttonFrames.append(frame)
        }
    }
    
    private func layoutSubmenuButtons() {
        for (index, button) in submenuButtons.enumerated() {
            if index < buttonFrames.count {
                if !isOpen {
                    // Position at main button when closed
                    let closedFrame = CGRect(
                        x: (bounds.width - submenuButtonSize) / 2,
                        y: (bounds.height - submenuButtonSize) / 2,
                        width: submenuButtonSize,
                        height: submenuButtonSize
                    )
                    updateButtonFrame(button, frame: closedFrame)
                } else {
                    // Position at calculated frame when open
                    let openFrame = buttonFrames[index]
                    updateButtonFrame(button, frame: openFrame)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func updateButtonFrame(_ button: UIButton, frame: CGRect) {
        button.frame = frame
        // Always ensure corner radius matches the button size to maintain circular shape
//        button.layer.cornerRadius = min(frame.width, frame.height) / 2
        button.layer.cornerRadius = frame.size.width / 2
    }
    
    private func updateMainButtonCornerRadius() {
        mainButton.layer.cornerRadius = buttonSize / 2
    }
    
    private func updateSubmenuButtonsCornerRadius() {
        for button in submenuButtons {
            // For submenu buttons, use their current frame size or default size
            let currentSize = max(button.frame.width, button.frame.height)
            let radiusSize = currentSize > 0 ? currentSize : submenuButtonSize
            button.layer.cornerRadius = radiusSize / 2
        }
    }
    
    // MARK: - Action Methods
    @objc private func mainButtonTapped() {
        // Don't toggle menu if currently dragging
        if !isDragging {
            toggleMenu()
        }
    }
    
    @objc private func submenuButtonTapped(_ sender: UIButton) {
        delegate?.floatingButtonDidTapSubmenu(at: sender.tag)
        closeMenu()
    }
    
    // MARK: - Drag Gesture Handling
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview, isDragEnabled else { return }
        
        let translation = gesture.translation(in: superview)
        let velocity = gesture.velocity(in: superview)
        
        switch gesture.state {
        case .began:
            initialDragPosition = center
            isDragging = false
            
        case .changed:
            let distance = sqrt(translation.x * translation.x + translation.y * translation.y)
            
            // Start dragging only if moved beyond threshold
            if !isDragging && distance > dragThreshold {
                isDragging = true
                // Close menu if open during drag
                if isOpen {
                    closeMenu()
                }
            }
            
            if isDragging {
                var newCenter = CGPoint(
                    x: initialDragPosition.x + translation.x,
                    y: initialDragPosition.y + translation.y
                )
                
                // Apply safe area constraints using configured safeMargin
                let safeTop = superview.safeAreaInsets.top + safeMargin
                let safeBottom = superview.bounds.height - superview.safeAreaInsets.bottom - safeMargin
//                let safeLeft = bounds.width / 2 + safeMargin
                let safeLeft = safeMargin

//                let safeRight = superview.bounds.width - bounds.width / 2 - safeMargin
                let safeRight = superview.bounds.width - safeMargin

//                newCenter.y = max(safeTop + bounds.height / 2, min(safeBottom - bounds.height / 2, newCenter.y))
                newCenter.y = max(safeTop + bounds.height / 2, min(safeBottom, newCenter.y))

                newCenter.x = max(safeLeft, min(safeRight, newCenter.x))
                
                center = newCenter
            }
            
        case .ended, .cancelled:
            if isDragging && snapToEdgeEnabled {
                snapToNearestEdge(velocity: velocity)
            }
            isDragging = false
            
        default:
            break
        }
    }
    
    private func snapToNearestEdge(velocity: CGPoint) {
        guard let superview = superview else { return }
        
        let screenMidX = superview.bounds.width / 2
        let shouldSnapToRight = center.x > screenMidX || (center.x == screenMidX && velocity.x > 0)
        
        // Calculate target position using configured safeMargin
        let targetX: CGFloat
        if shouldSnapToRight {
            targetX = superview.bounds.width - safeMargin
            layoutDirection = .counterClockwise
        } else {
//            targetX = bounds.width / 2 + safeMargin
            targetX = safeMargin

            layoutDirection = .clockwise
        }
        
        // Apply safe area constraints for Y position
        let safeTop = superview.safeAreaInsets.top + safeMargin
        let safeBottom = superview.bounds.height - superview.safeAreaInsets.bottom - safeMargin
//        let targetY = max(safeTop + bounds.height / 2, min(safeBottom - bounds.height / 2, center.y))
        let targetY = max(safeTop + bounds.height / 2, min(safeBottom, center.y))

        
        // Animate to target position
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: .curveEaseOut
        ) {
            self.center = CGPoint(x: targetX, y: targetY)
        } completion: { _ in
            // Recalculate button frames after position change
            self.setNeedsLayout()
        }
    }
    
    // MARK: - Public Methods
    public func toggleMenu() {
        if isOpen {
            closeMenu()
        } else {
            openMenu()
        }
    }
    
    public func openMenu() {
        guard !isOpen else { return }
        
        isOpen = true
        delegate?.floatingButtonDidOpen()
        
        // Animate submenu buttons
        for (index, button) in submenuButtons.enumerated() {
            let delay = TimeInterval(index) * 0.1
            let targetFrame = buttonFrames[index]
            
            UIView.animate(
                withDuration: animationDuration,
                delay: delay,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: .curveEaseOut
            ) {
                self.updateButtonFrame(button, frame: targetFrame)
                button.alpha = 1.0
                button.transform = .identity
            }
        }
        
        // Rotate main button
        mainButton.setImage(.init(systemName: "xmark"), for: .normal)
        UIView.animate(withDuration: 0.35, delay: 0) {
            self.mainButton.alpha = 1
        }
    }
    
    public func closeMenu() {
        guard isOpen else { return }
        
        isOpen = false
        delegate?.floatingButtonDidClose()
        
        // Animate submenu buttons back
        for (index, button) in submenuButtons.enumerated() {
            let delay = TimeInterval(submenuButtons.count - index - 1) * 0.05
            let mainButtonCenter = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
            let targetFrame = CGRect(
                x: mainButtonCenter.x - submenuButtonSize / 2,
                y: mainButtonCenter.y - submenuButtonSize / 2,
                width: submenuButtonSize,
                height: submenuButtonSize
            )
            
            UIView.animate(
                withDuration: animationDuration * 0.8,
                delay: delay,
                options: .curveEaseIn
            ) {
                self.updateButtonFrame(button, frame: targetFrame)
                button.alpha = self.initialOpacity
//                button.transform = CGAffineTransform(scaleX: self.initialScaling, y: self.initialScaling)
                button.transform = .identity
            }
        }
        
        // Rotate main button back

        mainButton.setImage(.init(systemName: "line.horizontal.3"), for: .normal)
        UIView.animate(withDuration: 0.35, delay: 0.55) {
            self.mainButton.alpha = 0.6
        }
    }
    
    // MARK: - Configuration Methods
    public func setDirection(_ direction: FloatingDirection) -> Self {
        self.direction = direction
        self.isCircleLayout = false
        calculateButtonFrames()
        return self
    }
    
    public func setAlignment(_ alignment: FloatingAlignment) -> Self {
        self.alignment = alignment
        calculateButtonFrames()
        return self
    }
    
    public func setSpacing(_ spacing: CGFloat) -> Self {
        self.spacing = spacing
        calculateButtonFrames()
        return self
    }
    
    public func setInitialScaling(_ scaling: CGFloat) -> Self {
        self.initialScaling = scaling
        for button in submenuButtons {
            if !isOpen {
                button.transform = CGAffineTransform(scaleX: scaling, y: scaling)
            }
        }
        return self
    }
    
    public func setInitialOpacity(_ opacity: CGFloat) -> Self {
        self.initialOpacity = opacity
        for button in submenuButtons {
            if !isOpen {
                button.alpha = opacity
            }
        }
        return self
    }
    
    public func setAnimationDuration(_ duration: TimeInterval) -> Self {
        self.animationDuration = duration
        return self
    }
    
    public func setButtonSize(_ size: CGFloat) -> Self {
        self.buttonSize = size
        updateMainButtonCornerRadius()
        setNeedsLayout()
        return self
    }
    
    public func setSubmenuButtonSize(_ size: CGFloat) -> Self {
        self.submenuButtonSize = size
        for button in submenuButtons {
            button.layer.cornerRadius = size / 2
        }
        calculateButtonFrames()
        return self
    }
    
    // Circle layout configuration
    public func setCircleLayout(radius: Double? = nil) -> Self {
        self.isCircleLayout = true
        if let radius = radius {
            self.radius = radius
        }
        calculateButtonFrames()
        return self
    }
    
    public func setStartAngle(_ angle: Double) -> Self {
        self.startAngle = angle
        if isCircleLayout {
            calculateButtonFrames()
        }
        return self
    }
    
    public func setEndAngle(_ angle: Double) -> Self {
        self.endAngle = angle
        if isCircleLayout {
            calculateButtonFrames()
        }
        return self
    }
    
    public func setLayoutDirection(_ direction: FloatingLayoutDirection) -> Self {
        self.layoutDirection = direction
        if isCircleLayout {
            calculateButtonFrames()
        }
        return self
    }
    
    // MARK: - Drag Configuration Methods
    public func setDragEnabled(_ enabled: Bool) -> Self {
        self.isDragEnabled = enabled
        panGestureRecognizer.isEnabled = enabled
        return self
    }
    
    public func setSnapToEdgeEnabled(_ enabled: Bool) -> Self {
        self.snapToEdgeEnabled = enabled
        return self
    }
    
    public func setSafeMargin(_ margin: CGFloat) -> Self {
        self.safeMargin = margin
        return self
    }
    
    public func setDragThreshold(_ threshold: CGFloat) -> Self {
        self.dragThreshold = threshold
        return self
    }
    
    // Color configuration
    public func setMainButtonColor(_ color: UIColor) -> Self {
        mainButton.backgroundColor = color
        return self
    }
    
    public func setSubmenuButtonColor(_ color: UIColor) -> Self {
        for button in submenuButtons {
            button.backgroundColor = color
        }
        return self
    }
    
    public func setSubmenuButtonColors(_ colors: [UIColor]) -> Self {
        for (index, button) in submenuButtons.enumerated() {
            if index < colors.count {
                button.backgroundColor = colors[index]
            }
        }
        return self
    }
    
    
    
}

// MARK: - Convenience Initializers
public extension FloatingButton {
    
    static func straight(
        mainButtonSystemName: String,
        submenuSystemNames: [String],
        direction: FloatingDirection = .right,
        dragEnabled: Bool = true
    ) -> FloatingButton {
        let button = FloatingButton(mainButtonSystemName: mainButtonSystemName, submenuSystemNames: submenuSystemNames)
        return button.setDirection(direction).setDragEnabled(dragEnabled)
    }
    
    static func circle(
        mainButtonSystemName: String,
        submenuSystemNames: [String],
        radius: Double = 100,
        dragEnabled: Bool = true
    ) -> FloatingButton {
        let button = FloatingButton(mainButtonSystemName: mainButtonSystemName, submenuSystemNames: submenuSystemNames)
        return button.setCircleLayout(radius: radius).setDragEnabled(dragEnabled)
    }
}

// MARK: - UIColor Extension for Hex Support
public extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
}

// MARK: - UIGestureRecognizerDelegate
extension FloatingButton: UIGestureRecognizerDelegate {
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow pan gesture to work alongside button tap gestures
        return true
    }
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panGestureRecognizer {
            // Since the gesture is now on mainButton, use superview as coordinate system
            guard let superview = superview else { return true }
            let velocity = panGestureRecognizer.velocity(in: superview)
            // Only begin pan gesture if there's significant movement
            return abs(velocity.x) > 50 || abs(velocity.y) > 50
        }
        return true
    }
}
