import UIKit

class RunCell: UICollectionViewCell {
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var elevationLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!

    // Create a cache to store images
    static var imageCache = NSCache<NSString, UIImage>()

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true

        // Set the corner radius for the contentView
        self.contentView.layer.cornerRadius = 10
        self.contentView.layer.masksToBounds = true

        // Set the corner radius for the cell layer
        self.layer.cornerRadius = 10
        self.layer.masksToBounds = false

        // Set the shadow for the cell layer
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.2
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowRadius = 4

        // Ensure labels are on top of the image view
        contentView.bringSubviewToFront(titleLabel)
        contentView.bringSubviewToFront(distanceLabel)
        contentView.bringSubviewToFront(elevationLabel)
        contentView.bringSubviewToFront(categoryLabel)

        // Setting up Auto Layout constraints programmatically
        setupConstraints()

        // Add gradient overlay to the cover image view
        addGradientOverlay()
    }

    func setupConstraints() {
        // Enable Auto Layout
        coverImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        elevationLabel.translatesAutoresizingMaskIntoConstraints = false
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Cover Image View constraints
            coverImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            coverImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            coverImageView.topAnchor.constraint(equalTo: contentView.topAnchor), // Fill the entire cell

            // Title label constraints
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            titleLabel.bottomAnchor.constraint(equalTo: distanceLabel.topAnchor, constant: -5),

            // Distance label constraints
            distanceLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            distanceLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            // Elevation label constraints
            elevationLabel.leadingAnchor.constraint(equalTo: distanceLabel.trailingAnchor, constant: 10),
            elevationLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            // Category label constraints
            categoryLabel.leadingAnchor.constraint(equalTo: elevationLabel.trailingAnchor, constant: 10),
            categoryLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    func configure(with run: Run, image: UIImage?) {
        titleLabel.text = run.name
        distanceLabel.text = run.distance
        elevationLabel.text = run.elevation
        categoryLabel.text = run.category

        // Use cached image if available
        if let cachedImage = RunCell.imageCache.object(forKey: run.id! as NSString) {
            coverImageView.image = cachedImage
        } else {
            coverImageView.image = image
        }
    }

    private func addGradientOverlay() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = coverImageView.bounds
        gradientLayer.colors = [UIColor.black.withAlphaComponent(0.6).cgColor, UIColor.clear.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
        coverImageView.layer.addSublayer(gradientLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        coverImageView.layer.sublayers?.forEach { layer in
            if layer is CAGradientLayer {
                layer.frame = coverImageView.bounds
            }
        }
    }
}
