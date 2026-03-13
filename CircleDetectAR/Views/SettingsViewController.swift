import UIKit

/// In-app settings panel presented as a page sheet.
final class SettingsViewController: UIViewController {

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismiss(_:))
        )
        setupTableView()
    }

    // MARK: - Public

    static func show(from presenter: UIViewController) {
        let vc = SettingsViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        presenter.present(nav, animated: true)
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func dismiss(_ sender: Any) {
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {

    private enum Section: Int, CaseIterable {
        case display, behaviour
        var title: String {
            switch self {
            case .display:   return "Display"
            case .behaviour: return "Behaviour"
            }
        }
    }

    private enum DisplayRow: Int, CaseIterable { case showDepth }
    private enum BehaviourRow: Int, CaseIterable { case haptics, confidenceThreshold }

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .display:    return DisplayRow.allCases.count
        case .behaviour:  return BehaviourRow.allCases.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let settings = SettingsManager.shared
        var cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell = UITableViewCell(style: .value1, reuseIdentifier: "cell")
        cell.selectionStyle = .none

        switch Section(rawValue: indexPath.section)! {
        case .display:
            switch DisplayRow(rawValue: indexPath.row)! {
            case .showDepth:
                cell.textLabel?.text = "Show Distance"
                let toggle = UISwitch()
                toggle.isOn = settings.showDepth
                toggle.addTarget(self, action: #selector(toggleDepth(_:)), for: .valueChanged)
                cell.accessoryView = toggle
            }
        case .behaviour:
            switch BehaviourRow(rawValue: indexPath.row)! {
            case .haptics:
                cell.textLabel?.text = "Haptic Feedback"
                let toggle = UISwitch()
                toggle.isOn = settings.hapticsEnabled
                toggle.addTarget(self, action: #selector(toggleHaptics(_:)), for: .valueChanged)
                cell.accessoryView = toggle
            case .confidenceThreshold:
                cell.textLabel?.text = "Min. Confidence"
                cell.detailTextLabel?.text = "\(Int(settings.confidenceThreshold * 100))%"
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .behaviour,
              BehaviourRow(rawValue: indexPath.row) == .confidenceThreshold else { return }
        presentConfidenceThresholdPicker()
    }

    // MARK: - Actions

    @objc private func toggleDepth(_ sender: UISwitch) {
        SettingsManager.shared.showDepth = sender.isOn
    }

    @objc private func toggleHaptics(_ sender: UISwitch) {
        SettingsManager.shared.hapticsEnabled = sender.isOn
    }

    private func presentConfidenceThresholdPicker() {
        let alert = UIAlertController(title: "Min. Confidence",
                                      message: "Only show results above this threshold.",
                                      preferredStyle: .actionSheet)
        let options: [Float] = [0.05, 0.10, 0.15, 0.20, 0.30, 0.40, 0.50]
        for value in options {
            let title = "\(Int(value * 100))%\(value == SettingsManager.shared.confidenceThreshold ? "  ✓" : "")"
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                SettingsManager.shared.confidenceThreshold = value
                self?.tableView.reloadData()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.sourceView = view
        present(alert, animated: true)
    }
}
