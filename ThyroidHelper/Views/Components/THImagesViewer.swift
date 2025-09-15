//
//  THImagesViewer.swift
//  ThyroidHelper
//
//  Created by Assistant on 2025/9/5.
//

import SwiftUI
import Photos

// MARK: - SwiftUI 包装
struct THImagesViewer: UIViewControllerRepresentable {
    let imageDatas: [Data]
    var initialIndex: Int = 0
    
    func makeUIViewController(context: Context) -> THImageViewerController {
        let vc = THImageViewerController(imageDatas: imageDatas, initialIndex: initialIndex)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: THImageViewerController, context: Context) {}
}

// MARK: - UIKit 容器控制器
class THImageViewerController: UIViewController {
    private let imageDatas: [Data]
    private var currentIndex: Int
    private var pageVC: THPageViewController!
    
    private let pageLabel = UILabel()
    
    init(imageDatas: [Data], initialIndex: Int) {
        self.imageDatas = imageDatas
        self.currentIndex = min(initialIndex, imageDatas.count - 1)
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        // 1. 添加 PageViewController
        pageVC = THPageViewController(imageDatas: imageDatas, initialIndex: currentIndex)
        pageVC.indexChanged = { [weak self] newIndex in
            self?.currentIndex = newIndex
            self?.updatePageLabel()
        }
        
        addChild(pageVC)
        view.addSubview(pageVC.view)
        pageVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        pageVC.didMove(toParent: self)
        
        setupTopBar()
        updatePageLabel()
    }
    
    private func setupTopBar() {
        let topBar = UIStackView()
        topBar.axis = .horizontal
        topBar.alignment = .center
        topBar.distribution = .equalSpacing
        topBar.translatesAutoresizingMaskIntoConstraints = false
        
        // 关闭按钮
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        }, for: .touchUpInside)
        
        // 页码
        pageLabel.textColor = .white
        pageLabel.font = .systemFont(ofSize: 14, weight: .medium)
        pageLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        pageLabel.layer.cornerRadius = 12
        pageLabel.clipsToBounds = true
        pageLabel.textAlignment = .center
        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let labelContainer = UIView()
        labelContainer.addSubview(pageLabel)
        NSLayoutConstraint.activate([
            pageLabel.centerXAnchor.constraint(equalTo: labelContainer.centerXAnchor),
            pageLabel.centerYAnchor.constraint(equalTo: labelContainer.centerYAnchor),
            pageLabel.heightAnchor.constraint(equalToConstant: 24),
            pageLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
        
        // 更多按钮
        let menuButton = UIButton(type: .system)
        menuButton.setImage(UIImage(systemName: "ellipsis.circle.fill"), for: .normal)
        menuButton.tintColor = .white
        menuButton.menu = makeMenu()
        menuButton.showsMenuAsPrimaryAction = true
        
        topBar.addArrangedSubview(closeButton)
        topBar.addArrangedSubview(labelContainer)
        topBar.addArrangedSubview(menuButton)
        
        view.addSubview(topBar)
        NSLayoutConstraint.activate([
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
        ])
    }
    
    private func updatePageLabel() {
        if imageDatas.count > 1 {
            pageLabel.text = " \(currentIndex + 1) / \(imageDatas.count) "
            pageLabel.isHidden = false
        } else {
            pageLabel.isHidden = true
        }
    }
    
    private func makeMenu() -> UIMenu {
        let saveAction = UIAction(title: "保存到相册", image: UIImage(systemName: "square.and.arrow.down")) { [weak self] _ in
            self?.saveCurrentImageToPhotos()
        }
        let shareAction = UIAction(title: "分享", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            self?.shareCurrentImage()
        }
        return UIMenu(children: [saveAction, shareAction])
    }
    
    private func saveCurrentImageToPhotos() {
        guard let imageData = imageDatas[safe: currentIndex],
              let uiImage = UIImage(data: imageData) else { return }
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else { return }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            }) { success, _ in
                if success {
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "已保存到相册", message: nil, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "好的", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    private func shareCurrentImage() {
        guard let imageData = imageDatas[safe: currentIndex],
              let uiImage = UIImage(data: imageData) else { return }
        let activityVC = UIActivityViewController(activityItems: [uiImage], applicationActivities: nil)
        present(activityVC, animated: true)
    }
}

// MARK: - UIPageViewController
class THPageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private let imageDatas: [Data]
    private(set) var currentIndex: Int
    var indexChanged: ((Int) -> Void)?
    
    init(imageDatas: [Data], initialIndex: Int) {
        self.imageDatas = imageDatas
        self.currentIndex = initialIndex
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal)
        self.dataSource = self
        self.delegate = self
        
        if let vc = getViewController(for: currentIndex) {
            setViewControllers([vc], direction: .forward, animated: false)
        }
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func getViewController(for index: Int) -> UIViewController? {
        guard imageDatas.indices.contains(index),
              let uiImage = UIImage(data: imageDatas[index]) else { return nil }
        
        let vc = UIViewController()
        vc.view.backgroundColor = .black
        vc.view.tag = index
        
        let zoomable = THZoomableImageView(image: uiImage)
        zoomable.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(zoomable)
        NSLayoutConstraint.activate([
            zoomable.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            zoomable.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            zoomable.topAnchor.constraint(equalTo: vc.view.topAnchor),
            zoomable.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor)
        ])
        
        return vc
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard currentIndex > 0 else { return nil }
        return getViewController(for: currentIndex - 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard currentIndex < imageDatas.count - 1 else { return nil }
        return getViewController(for: currentIndex + 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        if completed,
           let currentVC = viewControllers?.first,
           let index = viewControllers?.first.flatMap({ findIndex(for: $0) }) {
            currentIndex = index
            indexChanged?(currentIndex)
        }
    }
    
    private func findIndex(for vc: UIViewController) -> Int? {
        return vc.view.tag
    }
}

// MARK: - 可缩放图片视图
class THZoomableImageView: UIScrollView, UIScrollViewDelegate {
    private let imageView = UIImageView()
    let image: UIImage?
    
    init(image: UIImage) {
        self.image = image
        super.init(frame: .zero)
        
        self.delegate = self
        self.backgroundColor = .black
        self.minimumZoomScale = 1.0
        self.maximumZoomScale = 5.0
        self.showsHorizontalScrollIndicator = false
        self.showsVerticalScrollIndicator = false
        
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: self.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: self.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: self.heightAnchor)
        ])
        
        // 双击缩放
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        self.addGestureRecognizer(doubleTap)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > 1.0 {
            setZoomScale(1.0, animated: true)
        } else {
            let zoomRect = zoomRectForScale(scale: 2.0, center: gesture.location(in: imageView))
            zoom(to: zoomRect, animated: true)
        }
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    
    private func zoomRectForScale(scale: CGFloat, center: CGPoint) -> CGRect {
        let width = bounds.size.width / scale
        let height = bounds.size.height / scale
        let x = center.x - width / 2
        let y = center.y - height / 2
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - 安全下标
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
