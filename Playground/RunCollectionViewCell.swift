import UIKit

class RunCell: UICollectionViewCell {
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var elevationLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!

    static var imageCache = NSCache<NSString, UIImage>()

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
        setupConstraints()
        addGradientOverlay()
    }

    private func setupUI() {
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true

        contentView.layer.cornerRadius = 10
        contentView.layer.masksToBounds = true

        layer.cornerRadius = 10
        layer.masksToBounds = false

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4

        [titleLabel, distanceLabel, elevationLabel, categoryLabel].forEach {
            contentView.bringSubviewToFront($0!)
        }
    }

    private func setupConstraints() {
        [contentView, coverImageView, titleLabel, distanceLabel, elevationLabel, categoryLabel].forEach {
            $0?.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),

            coverImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            coverImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            coverImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            titleLabel.bottomAnchor.constraint(equalTo: distanceLabel.topAnchor, constant: -5),

            distanceLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            distanceLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            elevationLabel.leadingAnchor.constraint(equalTo: distanceLabel.trailingAnchor, constant: 10),
            elevationLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            categoryLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            categoryLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    private func addGradientOverlay() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        gradientLayer.colors = [UIColor.black.withAlphaComponent(0.6).cgColor, UIColor.clear.cgColor]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
        coverImageView.layer.addSublayer(gradientLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
        coverImageView.layer.sublayers?.first?.frame = bounds
    }

    func configure(with run: Run, image: UIImage?) {
        titleLabel.text = run.name
        distanceLabel.text = run.distance
        elevationLabel.text = run.elevation
        categoryLabel.text = run.category

        if let cachedImage = RunCell.imageCache.object(forKey: run.id! as NSString) {
            coverImageView.image = cachedImage
        } else if let image = image {
            coverImageView.image = image
            RunCell.imageCache.setObject(image, forKey: run.id! as NSString)
        } else {
            coverImageView.image = nil
        }
    }
}
