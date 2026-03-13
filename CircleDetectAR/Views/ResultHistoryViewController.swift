import UIKit

/// A slide-up panel showing the last N object identifications.
/// Present it by calling `show(from:)` on any view controller.
final class ResultHistoryViewController: UIViewController {

    // MARK: - UI

    private let containerView = UIView()
    private let handleBar     = UIView()
    private let titleLabel    = UILabel()
    private let clearButton   = UIButton(type: .system)
    private let tableView     = UITableView(frame: .zero, style: .plain)

    private var items: [ResultItem] = []
    private var observation: NSObjectProtocol?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupContainer()
        setupTableView()
        reload()
        observation = NotificationCenter.default.addObserver(
            forName: .resultHistoryDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
    }

    deinit {
        if let obs = observation { NotificationCenter.default.removeObserver(obs) }
    }

    // MARK: - Public

    /// Presents the history panel modally from `presenter`.
    static func show(from presenter: UIViewController) {
        let vc = ResultHistoryViewController()
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        presenter.present(vc, animated: true)
    }

    // MARK: - Setup

    private func setupBackground() {
        view.backgroundColor = UIColor.systemBackground
    }

    private func setupContainer() {
        titleLabel.text = "Recent Detections"
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        clearButton.setTitle("Clear", for: .normal)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.addTarget(self, action: #selector(clearHistory), for: .touchUpInside)

        view.addSubview(titleLabel)
        view.addSubview(clearButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            clearButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func setupTableView() {
        tableView.register(ResultHistoryCell.self, forCellReuseIdentifier: ResultHistoryCell.reuseID)
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.rowHeight  = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func reload() {
        items = ResultHistoryManager.shared.items
        tableView.reloadData()
    }

    @objc private func clearHistory() {
        ResultHistoryManager.shared.clear()
    }
}

// MARK: - UITableViewDataSource / Delegate

extension ResultHistoryViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if items.isEmpty {
            tableView.setEmptyMessage("No detections yet.\nDraw a circle around any object.")
        } else {
            tableView.restore()
        }
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ResultHistoryCell.reuseID,
                                                  for: indexPath) as! ResultHistoryCell
        cell.configure(with: items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - ResultHistoryCell

private final class ResultHistoryCell: UITableViewCell {

    static let reuseID = "ResultHistoryCell"

    private let nameLabel       = UILabel()
    private let detailLabel     = UILabel()
    private let confidenceBar   = UIProgressView(progressViewStyle: .default)
    private let timestampLabel  = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: ResultItem) {
        nameLabel.text      = item.label.capitalized
        if let d = item.depth {
            detailLabel.text = "\(Int(item.confidence * 100))% confidence · \(String(format: "%.1f", d)) m away"
        } else {
            detailLabel.text = "\(Int(item.confidence * 100))% confidence"
        }
        confidenceBar.progress = item.confidence
        confidenceBar.progressTintColor = confidenceColor(item.confidence)
        timestampLabel.text = item.relativeTime
    }

    private func confidenceColor(_ c: Float) -> UIColor {
        switch c {
        case 0.8...: return .systemGreen
        case 0.5...: return .systemOrange
        default:     return .systemRed
        }
    }

    private func setupLayout() {
        nameLabel.font      = .boldSystemFont(ofSize: 16)
        detailLabel.font    = .systemFont(ofSize: 13)
        detailLabel.textColor = .secondaryLabel
        timestampLabel.font = .systemFont(ofSize: 12)
        timestampLabel.textColor = .tertiaryLabel
        timestampLabel.textAlignment = .right

        [nameLabel, detailLabel, confidenceBar, timestampLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: timestampLabel.leadingAnchor, constant: -8),

            timestampLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            timestampLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timestampLabel.widthAnchor.constraint(equalToConstant: 70),

            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            confidenceBar.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 6),
            confidenceBar.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            confidenceBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            confidenceBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
}

// MARK: - UITableView empty-state helper

private extension UITableView {
    func setEmptyMessage(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.numberOfLines = 0
        backgroundView = label
    }

    func restore() {
        backgroundView = nil
    }
}
