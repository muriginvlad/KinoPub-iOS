//
//  DetailViewController.swift
//  KinoPub
//
//  Created by Евгений Дац on 19.12.2017.
//  Copyright © 2017 Evgeny Dats. All rights reserved.
//

import UIKit
import InteractiveSideMenu
import CustomLoader
import AlamofireImage
import TMDBSwift
import LKAlertController
import NTDownload
import NotificationBannerSwift
import GradientLoadingBar

class DetailViewController: UIViewController, SideMenuItemContent {
    let model = Container.ViewModel.videoItem()
    private let bookmarksModel = Container.ViewModel.bookmarks()
    private let commentsModel = Container.ViewModel.comments()
    private let logViewsManager = Container.Manager.logViews
    private let mediaManager = Container.Manager.media
    
    // MARK: class properties
    var offsetHeaderStop: CGFloat = 176  // At this offset the Header stops its transformations
    var distanceWLabelHeader: CGFloat = 30 // The distance between the top of the screen and the top of the White Label
    let control = UIRefreshControl()
    var refreshing: Bool = false
    var image: UIImage?
    var downloader = ImageDownloader.default
    var navigationBarHide = true
    var titleColor = UIColor.clear
    var storedOffsets = [Int: CGFloat]()
    
    // MARK: Outlet properties
    @IBOutlet weak var posterImageView: UIImageView!
    @IBOutlet weak var posterView: UIView!
    @IBOutlet weak var mainView: UIView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var headerImageView: UIImageView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var gradientView: UIView!
    @IBOutlet weak var containerInMainView: UIView!
    @IBOutlet weak var ruTitleLabel: UILabel!
    @IBOutlet weak var enTitleLabel: UILabel!
    @IBOutlet weak var yearAndCountriesLabel: UILabel!
    @IBOutlet weak var watchedView: UIView!
    @IBOutlet weak var inAirView: UIView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var episodeLabel: UILabel!
    @IBOutlet weak var downloadButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        TMDBConfig.apikey = Config.themoviedb.key
        
        navigationController?.navigationBar.clean(navigationBarHide)
//        navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: titleColor]
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        } else {
            // Fallback on earlier versions
        }

        configView()
        configTableView()
        configTitle()
        delegates()
        configHeaderImageView()
        configPullToRefresh()
        configYearAndCountries()
        configInAirView()
        receiveTMDBBackgroundImage()
        configAfterRefresh()
        loadData()
        model.loadSimilarsVideo()
        commentsModel.loadTopComments(for: (model.item.id?.string)!)
        commentsModel.delegate = self
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.clean(navigationBarHide)
//        navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: titleColor]
        if navigationBarHide { self.title = nil }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configOffset()
    }
    
    override func viewWillLayoutSubviews() {
//        tableView.tableFooterView?.frame.size = CGSize(width: tableView.frame.width, height: CGFloat(195))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
//        navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.kpOffWhite]
        navigationController?.navigationBar.clean(false)
        super.viewWillDisappear(animated)
        endLoad()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    func sizeFooterToFit() {
        if let footerView = tableView.tableFooterView {
            footerView.setNeedsLayout()
            footerView.layoutIfNeeded()
            
            let height = footerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
            var frame = footerView.frame
            frame.size.height = height
            footerView.frame = frame
            
            tableView.tableFooterView = footerView
        }
    }
    
    // MARK: - Configs
    func configView() {
        view.backgroundColor = .kpBackground
        watchedView.backgroundColor = .kpMarigold
        ruTitleLabel.textColor = .kpOffWhite
        enTitleLabel.textColor = .kpGreyishBrown
        yearAndCountriesLabel.textColor = .kpGreyishTwo
        inAirView.backgroundColor = .kpOffWhite
        episodeLabel.textColor = .kpOffWhite
        playButton.isHidden = true
        
        posterView.dropShadow(color: UIColor.black, opacity: 0.3, offSet: CGSize(width: 0, height: 2), radius: 6, scale: true)
    }
    
    func delegates() {
        tableView.delegate = self
        tableView.dataSource = self
        logViewsManager.addDelegate(delegate: self)
        model.delegate = self
        bookmarksModel.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(modelDidUpdate), name: NSNotification.Name.VideoItemDidUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: NSNotification.Name.PlayDidFinish, object: nil)
    }

    func configTableView() {
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
//        let fixWrapper = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 195))
//        let tableFooterView: TableFooterView = TableFooterView.fromNib()
//        tableFooterView.autoresizingMask = [.flexibleWidth]
//        fixWrapper.addSubview(tableFooterView)
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.register(UINib(nibName: String(describing: RatingTableViewCell.self), bundle: Bundle.main), forCellReuseIdentifier: String(describing: RatingTableViewCell.self))
        tableView.register(UINib(nibName: String(describing: ButtonsTableViewCell.self), bundle: Bundle.main), forCellReuseIdentifier: String(describing: ButtonsTableViewCell.self))
        tableView.register(UINib(nibName: String(describing: DescTableViewCell.self), bundle: Bundle.main), forCellReuseIdentifier: String(describing: DescTableViewCell.self))
        tableView.register(UINib(nibName: String(describing: InfoTableViewCell.self), bundle: Bundle.main), forCellReuseIdentifier: String(describing: InfoTableViewCell.self))
        tableView.register(UINib(nibName: String(describing: SeasonTableViewCell.self), bundle: Bundle.main), forCellReuseIdentifier: String(describing: SeasonTableViewCell.self))
        tableView.register(UINib(nibName: String(describing: TrailerTableViewCell.self), bundle: Bundle.main), forCellReuseIdentifier: String(describing: TrailerTableViewCell.self))
        tableView.register(UINib(nibName: String(describing: CastTableViewCell.self), bundle: Bundle.main), forCellReuseIdentifier: String(describing: CastTableViewCell.self))
        tableView.register(UINib(nibName: String(describing: SimilarTableViewCell.self), bundle: Bundle.main), forCellReuseIdentifier: String(describing: SimilarTableViewCell.self))
        tableView.register(UINib(nibName: String(describing: CommentsTableViewCell.self), bundle: Bundle.main), forCellReuseIdentifier: String(describing: CommentsTableViewCell.self))
        tableView.register(UINib(nibName: String(describing: AllCommentsTableViewCell.self), bundle: Bundle.main), forCellReuseIdentifier: String(describing: AllCommentsTableViewCell.self))
    }
    
    func configOffset() {
        if let navBarHeight = navigationController?.navigationBar.frame.height {
            offsetHeaderStop = headerView.bounds.height - (navBarHeight + UIApplication.shared.statusBarFrame.height)
        }
        distanceWLabelHeader = UIApplication.shared.statusBarFrame.height + 10
    }
    
    func configPullToRefresh() {
        control.addTarget(self, action: #selector(refresh), for: UIControl.Event.valueChanged)
        control.tintColor = .kpOffWhite
        if #available(iOS 10.0, *) {
            tableView.refreshControl = control
        } else {
            tableView.addSubview(control)
        }
    }
    
    func configTitle() {
        if let title = model.item.title?.components(separatedBy: " / ") {
            ruTitleLabel.attributedText = title[0].attributedString
            ruTitleLabel.numberOfLines = 0
            ruTitleLabel.addCharactersSpacing(0.4)
            self.title = title[0]
//            model.mediaItem.title = title[0]
            enTitleLabel.text = title.count > 1 ? title[1] : ""
            enTitleLabel.numberOfLines = 0
            enTitleLabel.addCharactersSpacing(-0.4)
        }
    }
    
    func configYearAndCountries() {
        if let year = model.item.year, let countries = model.item.countries {
            yearAndCountriesLabel.isHidden = false
            var yearAndCountries = "\(year)"
            for country in countries {
                yearAndCountries += ", \(country.title ?? "")"
            }
            yearAndCountriesLabel.attributedText = yearAndCountries.attributedString
            yearAndCountriesLabel.numberOfLines = 0
            yearAndCountriesLabel.addCharactersSpacing(-0.1)
        } else {
            yearAndCountriesLabel.isHidden = true
        }
    }
    
    func configureHeaderImage(with image: UIImage) {
        headerImageView.image = image
    }
    
    func configHeaderImageView() {
        headerImageView.image = image
        posterImageView.image = image
        headerView.clipsToBounds = true
    }
    
    func configPosterWatched() {
        watchedView.isHidden = !(model.item?.videos?.first?.watching?.status == Status.watched)
    }
    
    func configInAirView() {
        inAirView.isHidden = true
        guard model.item.type == ItemType.shows.rawValue ||
            model.item.type == ItemType.docuserial.rawValue ||
            model.item.type == ItemType.tvshows.rawValue else { return }
        inAirView.isHidden = model.item.finished!
    }
    
    func configPlayButton() {
        playButton.isHidden = model.mediaItems.first?.url != nil ? false : true
    }
    
    func configEpisodeLabel() {
        if let season = model.mediaItems.first?.season, let number = model.mediaItems.first?.video {
            episodeLabel.attributedText = "Сезон \(season), серия \(number)".attributedString
//            episodeLabel.addLineHeight(min: 20, max: 20)
            
        } else {
            episodeLabel.text = ""
        }
    }
    
    func configBarButtonItems() {
        
    }
    
    func configAfterRefresh() {
        configPosterWatched()
        configPlayButton()
        configEpisodeLabel()
//        tableView.reloadData()
    }
    
    func loadData() {
        beginLoad()
        model.loadItemsInfo()
    }
    
    func beginLoad() {
        refreshing = true
        GradientLoadingBar.shared.show()
    }
    
    func endLoad() {
        refreshing = false
        tableView.reloadData()
        GradientLoadingBar.shared.hide()
        control.endRefreshing()
    }
    
    @objc func refresh() {
        model.mediaItems.removeAll()
        loadData()
    }
    
    @objc func modelDidUpdate() {
        configAfterRefresh()
        endLoad()
    }
    
    // MARK: - Orientations
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        //        if UIDevice.current.userInterfaceIdiom == .pad {
        //            return .landscape
        //        }else {
        //            return .portrait
        //        }
        return [.all]
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .landscapeRight
        } else {
            return .portrait
        }
    }

}

extension DetailViewController {
    func setButtonImage(_ button: UIButton?, _ image: String) {
        button?.setImage(UIImage(named: image)?.withRenderingMode(.alwaysTemplate), for: .normal)
    }
    
    func receiveTMDBBackgroundImage() {
        if let imdbID = model.item.imdb {
            FindMDB.find(id: imdbID.fullIMDb, external_source: .imdb_id, completion: { [weak self] (_, results) in
                guard let strongSelf = self else { return }
                if let results = results {
                    if let urlString = results.movie_results.first?.backdrop_path, let tmdbID = results.movie_results.first?.id {
                        strongSelf.receiveTMDBMoreForMovie(with: tmdbID)
                        strongSelf.downloadImage(from: URL(string: Config.themoviedb.backdropBase + urlString)!)
                    } else if let urlString = results.tv_results.first?.backdrop_path, let tmdbID = results.tv_results.first?.id {
                        strongSelf.receiveTMDBMore(with: tmdbID)
                        strongSelf.downloadImage(from: URL(string: Config.themoviedb.backdropBase + urlString)!)
                    } else {
                        strongSelf.receivePosterImage()
                    }
                }
            })
        } else {
            receivePosterImage()
        }
    }
    
    func downloadImage(from url: URL) {
        downloader.download(URLRequest(url: url), completion: { [weak self] (response) in
            guard let strongSelf = self else { return }
            if let image = response.result.value {
                strongSelf.configureHeaderImage(with: image)
                return
            }
        })
    }
    
    func receivePosterImage() {
        if let poster = model.item.posters?.big {
            downloader.download(URLRequest(url: URL(string: poster)!), completion: { [weak self] (response) in
                guard let strongSelf = self else { return }
                if let image = response.result.value {
                    strongSelf.posterImageView.image = image
                    strongSelf.configureHeaderImage(with: image)
                }
            })
        }
    }
    
    func receiveTMDBMore(with tmdbID: Int) {
        TVMDB.tv(tvShowID: tmdbID, language: "ru") { [weak self] (_, series) in
            guard let strongSelf = self else { return }
            guard let series = series else { return }
            strongSelf.model.item.networks = series.networks.compactMap{$0.name}.joined(separator: ", ")
        }
    }
    
    func receiveTMDBMoreForMovie(with tmdbID: Int) {
        MovieMDB.movie(movieID: tmdbID, language: "ru") { [weak self] (_, movies) in
            guard let strongSelf = self else { return }
            guard let movies = movies else { return }
            strongSelf.model.item.networks = movies.production_companies?.compactMap{$0.name}.joined(separator: ", ")
        }
    }
    
    func playVideo() {
        guard model.mediaItems.first?.url != nil else {
            Helper.showError("Что-то пошло не так")
            return
        }
        mediaManager.playVideo(mediaItems: Config.shared.streamType != "hls4" ? [model.mediaItems.first!] : model.mediaItems, userinfo: nil)
    }
    
    func showQualitySelectAction(inView view: UIView? = nil, forButton button: UIBarButtonItem? = nil, play: Bool = false, season: Int? = nil) {
        let actionVC = ActionSheet(message: "Выберите качество", blurStyle: .dark).tint(.kpOffWhite)
        
        if let season = season {
            guard let files = model.getSeason(season)?.episodes.first?.files else { return }
            for (index, file) in files.enumerated() {
                actionVC.addAction(file.quality, style: .default, handler: { [weak self] (action) in
                    guard let strongSelf = self else { return }
                    strongSelf.downloadSeason(season: season, index: index, quality: file.quality)
                })
            }
        } else {
            guard let files = model.files else { return }
            for file in files {
                actionVC.addAction(file.quality, style: .default, handler: { [weak self] (_) in
                    guard let strongSelf = self else { return }
                    if play {
                        var urlString = ""
                        if Config.shared.streamType == "http" {
                            urlString = file.url.http ?? ""
                        } else if Config.shared.streamType == "hls" {
                            urlString = file.url.hls ?? ""
                        }
                        strongSelf.model.mediaItems[0].url = URL(string: urlString)
                        strongSelf.playVideo()
                    } else {
                        guard let url = file.url.http else { return }
                        strongSelf.showDownloadAction(with: url, quality: file.quality, inView: view, forButton: button)
                    }
                })
            }
        }
        actionVC.addAction("Отменить", style: .cancel)
        if let button = button {
            actionVC.setBarButtonItem(button)
        } else if let view = view {
            actionVC.setPresentingSource(view)
        }
        actionVC.show()
        if #available(iOS 10.0, *) { Helper.hapticGenerate(style: .medium) }
    }
    
    func showDownloadAction(with url: String, quality: String, inView view: UIView? = nil, forButton button: UIBarButtonItem? = nil) {
        let name = (self.model.item?.title?.replacingOccurrences(of: " /", with: ";"))! + "; \(quality).mp4"
        let poster = self.model.item?.posters?.small
        Share().showActions(url: url, title: name, quality: quality, poster: poster!, inView: view, forButton: button)
    }
    
    func showSelectSeasonAction(inView view: UIView? = nil, forButton button: UIBarButtonItem? = nil) {
        guard let seasons = model.item.seasons else { return }
        let actionVC = ActionSheet(blurStyle: .dark).tint(.kpOffWhite)
        
        for (index, season) in seasons.enumerated() {
            actionVC.addAction("Сезон \(season.number)", style: .default, handler: { [weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.showQualitySelectAction(inView: view, forButton: button, season: index)
            })
        }
        actionVC.addAction("Отменить", style: .cancel)
        if let button = button {
            actionVC.setBarButtonItem(button)
        } else if let view = view {
            actionVC.setPresentingSource(view)
        }
        actionVC.show()
        if #available(iOS 10.0, *) { Helper.hapticGenerate(style: .medium) }
    }
    
    func downloadSeason(season: Int, index: Int, quality: String) {
        guard let episodes = model.getSeason(season)?.episodes else { return }
        for episode in episodes {
            guard let title = self.model.item?.title?.replacingOccurrences(of: " /", with: ";") else { continue }
            let name = title + "; Сезон \(self.model.getSeason(season)?.number ?? 0), Эпизод \(episode.number ?? 0)."  + "\(quality).mp4"
            let poster = self.model.item?.posters?.small
            guard let url = episode.files?[index].url?.http else { continue }
            NTDownloadManager.shared.addDownloadTask(urlString: url, fileName: name, fileImage: poster)
        }
        Helper.showSuccessStatusBarBanner("Сезон добавлен в загрузки")
    }
}

// MARK: - Buttons
extension DetailViewController {
    @IBAction func playButtonTapped(_ sender: Any) {
        Config.shared.streamType == "hls4" ? playVideo() : showQualitySelectAction(inView: playButton, play: true)
    }
    
    @IBAction func shareButtonTapped(_ sender: Any) {
        var sharingActivities = [UIActivity]()
        sharingActivities.append(SafariActivity())
        let url = URL(string: "\(Config.shared.kinopubDomain)/item/view/\((model.item?.id)!)")
        let activityViewController = UIActivityViewController(activityItems: [url!], applicationActivities: sharingActivities)
        activityViewController.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
        activityViewController.view.tintColor = .kpBlack
        self.present(activityViewController, animated: true, completion: nil)
        if #available(iOS 10.0, *) { Helper.hapticGenerate(style: .medium) }
    }
    
    @IBAction func downloadButtonTapped(_ sender: Any) {
        switch model.item?.type {
        case ItemType.shows.rawValue, ItemType.docuserial.rawValue, ItemType.tvshows.rawValue:
            showSelectSeasonAction(forButton: downloadButton)
        default:
            showQualitySelectAction(forButton: downloadButton)
        }
    }
}

// MARK: - Navigation
extension DetailViewController {
    static func storyboardInstance() -> DetailViewController? {
        let storyboard = UIStoryboard(name: String(describing: self), bundle: nil)
        return storyboard.instantiateInitialViewController() as? DetailViewController
    }
    
    @objc func showSeasonVC(_ sender: KPGestureRecognizer) {
        if let seasonVC = SeasonTableViewController.storyboardInstance() {
            if let indexPathRow = sender.indexPathRow {
                seasonVC.model = model
                seasonVC.indexPathSeason = indexPathRow
            }
            navigationController?.pushViewController(seasonVC, animated: true)
        }
    }
}

// MARK: - UIScrollViewDelegate
extension DetailViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
        }
        
        let offset = scrollView.contentOffset.y
        var headerTransform = CATransform3DIdentity
        
        // PULL DOWN  ----------
        if offset < 0 {
            let headerScaleFactor: CGFloat = -(offset) / headerView.bounds.height
            let headerSizeVariation = ((headerView.bounds.height * (1.0 + headerScaleFactor)) - headerView.bounds.height) / 2
            headerTransform = CATransform3DTranslate(headerTransform, 0, headerSizeVariation, 0)
            headerTransform = CATransform3DScale(headerTransform, 1.0 + headerScaleFactor, 1.0 + headerScaleFactor, 0)
            
            // Hide views if scrolled super fast
            headerView.layer.zPosition = 0
            headerView.layer.transform = headerTransform
        }
            // SCROLL UP/DOWN ----------
        else {
            // Header ----------
            headerTransform = CATransform3DTranslate(headerTransform, 0, max(-offsetHeaderStop, -offset), 0)

//            let alignToNameLabel = -offset - gradientView.frame.origin.y + headerView.frame.height + offsetHeaderStop
//            navigationBarBackgroundAlpha = min(1.0, (offset - alignToNameLabel) / distanceWLabelHeader)
            
//            if (offset > (-headerView.height + CGFloat(offsetHeaderStop * 2))) {
//                let alpha = (offset - (-headerView.height + CGFloat(offsetHeaderStop * 2))) / CGFloat(offsetHeaderStop)
//                navigationBarBackgroundAlpha = alpha
//            } else {
//                navigationBarBackgroundAlpha = 0
//            }
            
            if offset >= offsetHeaderStop - gradientView.height {
                navigationBarHide = false
                title = ruTitleLabel.text
            } else {
                title = nil
                navigationBarHide = true
            }
        }
        // Apply Transformations
        headerView.layer.transform = headerTransform
        navigationController?.navigationBar.clean(navigationBarHide)
//        navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: titleColor]
    }
}

// MARK: - UITableViewDataSource
extension DetailViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 10
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 3:
            return model.item.trailer == nil ? 0 : 1
        case 4:
            if let count = model.item?.seasons?.count {
                return count
            } else if let count = model.item?.videos?.count, count > 1 {
                return 1
            }
            return 0
        case 6:
            return (model.item?.cast != "" || model.item?.director != "" || model.item.kinopoiskData?.creators != nil) ? 1 : 0
        case 7:
            return model.similarItems.count > 0 ? 1 : 0
        case 8:
            return commentsModel.comments.count
        case 9:
            return commentsModel.comments.count > 0 ? 1 : 0
        default:
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: RatingTableViewCell.self), for: indexPath) as! RatingTableViewCell
            cell.selectionStyle = .none
            cell.configure(withItem: model.item!)
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: ButtonsTableViewCell.self), for: indexPath) as! ButtonsTableViewCell
            cell.selectionStyle = .none
            cell.config(withModel: model, bookmarksModel: bookmarksModel)
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: DescTableViewCell.self), for: indexPath) as! DescTableViewCell
            cell.selectionStyle = .none
            cell.configure(withItem: model.item!)
            return cell
        case 5:
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: InfoTableViewCell.self), for: indexPath) as! InfoTableViewCell
            cell.selectionStyle = .none
            cell.configure(with: model.item!)
            return cell
        case 6:
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: CastTableViewCell.self), for: indexPath) as! CastTableViewCell
            cell.selectionStyle = .none
            cell.configure(with: model.item?.cast, directors: model.item?.director)
            if let creators = model.item.kinopoiskData?.creators {
                cell.config(with: creators)
            }
            return cell
        case 4:
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: SeasonTableViewCell.self), for: indexPath) as! SeasonTableViewCell
            cell.selectionStyle = .none
            cell.config(withModel: model, index: indexPath.row)
            let tap = KPGestureRecognizer(target: self, action: #selector(showSeasonVC(_:)))
            cell.addGestureRecognizer(tap)
            tap.indexPathRow = indexPath.row
            
            return cell
        case 3:
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: TrailerTableViewCell.self), for: indexPath) as! TrailerTableViewCell
            cell.selectionStyle = .none
            cell.config(with: model.item.trailer)
            return cell
        case 7:
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: SimilarTableViewCell.self), for: indexPath) as! SimilarTableViewCell
            cell.selectionStyle = .none
            cell.config(withModel: model)
            return cell
        case 8:
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: CommentsTableViewCell.self), for: indexPath) as! CommentsTableViewCell
            cell.selectionStyle = .none
            cell.disableDepth()
            cell.config(with: commentsModel.comments[indexPath.row])
            return cell
        case 9:
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: AllCommentsTableViewCell.self), for: indexPath) as! AllCommentsTableViewCell
            cell.selectionStyle = .none
            cell.set(id: model.item.id)
            return cell
        default:
            return UITableViewCell()
        }
        
    }
}

// MARK: - UITableViewDelegate
extension DetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let tableViewCell = cell as? SeasonTableViewCell else { return }
        tableViewCell.collectionViewOffset = storedOffsets[indexPath.row] ?? -15
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let tableViewCell = cell as? SeasonTableViewCell else { return }
        storedOffsets[indexPath.row] = tableViewCell.collectionViewOffset
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 8 else { return UIView(frame: .zero) }
        guard commentsModel.comments.count > 0 else { return UIView(frame: .zero) }
        let screenSize = UIScreen.main.bounds.width
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: screenSize, height: 26))
        let label = UILabel(text: "КОММЕНТАРИИ ПОЛЬЗОВАТЕЛЕЙ")
        label.sizeToFit()
        label.x = 15
        label.height = 12
        label.font = UIFont.titleSmall
        label.textColor = UIColor.kpGreyishBrown
        headerView.backgroundColor = .clear
        headerView.addSubview(label)
        label.center.y = headerView.height / 2
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard commentsModel.comments.count > 0 else { return 0 }
        return section == 8 ? 26 : 0
    }
}

// MARK: - VideoItemModelDelegate
extension DetailViewController: VideoItemModelDelegate {
    func didLoadKpInfo() {
        tableView.reloadSections([6], with: .automatic)
    }
    
    func didUpdateSimilar() {
//        tableView.reloadData()
        tableView.reloadSections([7], with: .automatic)
    }
}

// MARK: - BookmarksModelDelegate, LogViewsManagerDelegate
extension DetailViewController: BookmarksModelDelegate, LogViewsManagerDelegate {
    func didChangeStatus(manager: LogViewsManager) {
        refresh()
    }
    
    func didAddedBookmarks() {
        refresh()
    }
    
    func didToggledWatchlist(toggled: Bool) {
        model.item?.inWatchlist = toggled
        refresh()
    }
}

// MARK: - CommentsModelDelegate
extension DetailViewController: CommentsModelDelegate {
    func didUpdateComments() {
        tableView.reloadSections([8, 9], with: .automatic)
    }
}
