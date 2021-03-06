import JavaScriptCore

// MARK: - Colors


func isSchemeLight() -> Bool {
    return darkSchemeColor().isWhiteText
}

func darkSchemeColor(key: Int) -> UIColor {
    guard key < Settings.colorsHEXs.count else {
//        setInt(forKey: "Color", val: 1)
        return UIColor.init(hex: Settings.colorsHEXs[1])
    }
    return UIColor.init(hex: Settings.colorsHEXs[key])
}

class ViewControllerErrorHandler: UIViewController {
    var status: Status = .loading
    var goToLogin = false
    var errorDescription = ""
    var refreshControl = UIRefreshControl()
    var table = UITableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    func errorHandle(_ statusCode: Int) {
        switch statusCode {
        case 400:
            errorDescription = "Неверные данные в запросе"
        case 401:
            DispatchQueue.main.async {
                self.goToLogin = true
                let loginVC = Login()
                loginVC.navigationBarHeight = self.navigationController?.navigationBar.frame.height ?? 0
                loginVC.modalTransitionStyle = .coverVertical
                self.present(loginVC)
            }
        case 402:
            errorDescription = "Нет доступа к сервесу"
        case 404:
            errorDescription = "Неверный путь запроса"
        case 405:
            errorDescription = "Неверный метод запроса"
        case 500:
            errorDescription = "Фатальная ошибка на сервере"
        case 501:
            errorDescription = "Запрос не реализован на сервере"
        case 502:
            errorDescription = "Ошибка на сервере школы"
        default:
            errorDescription = "Неизвестная ошибка"
        }
    }
    
    func reloadTable() {
        DispatchQueue.main.async {
            self.refreshControl.stop
            self.table.reloadData()
        }
    }
    
    func showAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Ошибка:", message: self.errorDescription, preferredStyle: .alert)
            alert.addOkAction
            UIApplication.shared.keyWindow?.rootViewController?.present(alert)
        }
    }
    
    func load() {
        fatalError("Must Override")
    }
    
    func loadData<T>(jsonData: Data?, method: String, methodType: String = "POST", jsonStruct: T.Type, completion: @escaping (_ data: Data, _ json: Decodable) -> Void ) -> Void where T : Decodable {
        let sessionName = UserDefaults.standard.value(forKey: "sessionName") as? String ?? ""
        let cookie = UserDefaults.standard.value(forKey: sessionName) as? String ?? ""
        guard !sessionName.isEmpty && !cookie.isEmpty else {
            print("No Authorization")
            goToLogin = true
            let loginVC = Login()
            loginVC.navigationBarHeight = self.navigationController?.navigationBar.frame.height ?? 0
            loginVC.modalTransitionStyle = .coverVertical
            present(loginVC)
            return
        }
        var request = URLRequest(url: URL(string: "http://77.73.26.195:8000/\(method)")!)
        request.httpMethod = methodType
        print("*** request json ***")
        print(String.init(data: jsonData!, encoding: .utf8))
        request.setValue(sessionName, forHTTPHeaderField: "sessionName")
        request.setValue(cookie, forHTTPHeaderField: sessionName)
        request.httpBody = jsonData
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil,
                let data = data,
                let httpResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async {
                        self.status = .error
                        self.errorDescription = ReachabilityManager.shared.isNetworkAvailable ? error?.localizedDescription ?? "Нет ответа от сервера" : "Вероятно, соединение с интернетом прервано"
                        self.table.reloadData()
                    }
                    return
            }
            print(httpResponse)
            print(String.init(data: data, encoding: .utf8))
            guard httpResponse.statusCode == 200 else {
                self.status = .error
                self.errorHandle(httpResponse.statusCode)
                if !self.goToLogin {
                    self.reloadTable()
                }
                return
            }
            let decoder = JSONDecoder()
            if let json = try? decoder.decode(jsonStruct, from: data) {
                completion(data, json)
            } else {
                self.status = .error
                self.errorDescription = "Не удалось интерпретировать json"
                self.reloadTable()
            }
        }.resume()
    }
    
    func postData(jsonData: Data?, method: String, methodType: String = "POST", completion: @escaping () -> Void ) {
        let sessionName = UserDefaults.standard.value(forKey: "sessionName") as? String ?? ""
        let cookie = UserDefaults.standard.value(forKey: sessionName) as? String ?? ""
        guard !sessionName.isEmpty && !cookie.isEmpty else {
            print("No Authorization")
            goToLogin = true
            let loginVC = Login()
            loginVC.navigationBarHeight = self.navigationController?.navigationBar.frame.height ?? 0
            loginVC.modalTransitionStyle = .coverVertical
            present(loginVC)
            return
        }
        var request = URLRequest(url: URL(string: "http://77.73.26.195:8000/\(method)")!)
        request.httpMethod = methodType
        print("*** request json ***")
        print(String.init(data: jsonData!, encoding: .utf8))
        request.setValue(sessionName, forHTTPHeaderField: "sessionName")
        request.setValue(cookie, forHTTPHeaderField: sessionName)
        request.httpBody = jsonData
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil,
                let data = data,
                let httpResponse = response as? HTTPURLResponse else {
                    self.errorDescription = ReachabilityManager.shared.isNetworkAvailable ? error?.localizedDescription ?? "Нет ответа от сервера" : "Вероятно, соединение с интернетом прервано"
                    self.table.reloadData()
                    self.showAlert()
                    return
            }
            print(httpResponse)
            print(String.init(data: data, encoding: .utf8))
            guard httpResponse.statusCode == 200 else {
                self.errorHandle(httpResponse.statusCode)
                self.showAlert()
                completion()
                return
            }            
        }.resume()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if !getString(forKey: "username").isEmpty && !getString(forKey: "password").isEmpty && goToLogin {
            goToLogin = false
            load()
        }
    }
}

func lightSchemeColor() -> UIColor {
    let color = darkSchemeColor()
    let red = color.redValue
    let green = color.greenValue
    let blue = color.blueValue
    let minimum = min(min(red, green),blue)
    let maximum = max(max(red, green),blue)
    let luminance = ((minimum + maximum) / 2) * 0.85
    let saturation = minimum == maximum ? 0 : luminance < 0.5 ? (maximum-minimum)/(maximum+minimum) : (maximum-minimum)/(2.0-maximum-minimum)
    let hue = (red == maximum ? (green-blue)/(maximum-minimum) : green == maximum ? 2.0 + (blue-red)/(maximum-minimum) : 4.0 + (red-green)/(maximum-minimum))/6
    guard saturation != 0  else { return UIColor(red: luminance, green: luminance, blue: luminance, alpha: 1) }
    let t1 = luminance < 0.5 ? luminance * (1.0+saturation) : luminance + saturation - luminance * saturation
    let t2 = 2 * luminance - t1
    var tr = hue + 1/3
    var tg = hue
    var tb = hue - 1/3
    while tr < 0 { tr += 1 }
    while tr > 1 { tr -= 1 }
    while tg < 0 { tg += 1 }
    while tg > 1 { tg -= 1 }
    while tb < 0 { tb += 1 }
    while tb > 1 { tb -= 1 }
    func test(_ temporary: CGFloat) -> CGFloat {
        if 6 * temporary < 1 { return t2 + (t1 - t2) * 6 * temporary }
        if 2 * temporary < 1 { return t1 }
        if 3 * temporary < 2 { return t2 + (t1 - t2) * (2/3 - temporary) * 6 }
        return t2
    }
    return UIColor(red: test(tr), green: test(tg), blue: test(tb), alpha: 1)
}

func darkSchemeColor() -> UIColor {
    return UIColor.init(hex: Settings.colorsHEXs[getColor()])
}

/// Returns hash of given text
func hashMD5(_ text: String) -> String {
    let context = JSContext()
    let path = Bundle.main.path(forResource: "md5", ofType: "js")
    let contentData = FileManager.default.contents(atPath: path!)
    let content = NSString(data: contentData!, encoding: String.Encoding.utf8.rawValue) as String?
    context?.setObject(text, forKeyedSubscript: "pass" as (NSCopying & NSObjectProtocol)?)
    let result = context?.evaluateScript(content)
    return result?.toString() ?? ""
}

func selectUsers(_ sender: AnyObject, _ viewController: UIViewController) {
    let 🚨 = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    let selectedUser = getFirstUser()
    for child in getUsers() {
        let action = UIAlertAction(title: child.username, style: .default) { _ in
            setFirstUser(child.id)
        }
        action.setValue(child.id == selectedUser, forKey: "checked")
        🚨.addAction(action)
    }
    if let presenter = 🚨.popoverPresentationController {
        presenter.sourceView = sender as? UIView
        presenter.sourceRect = sender.bounds
    }
    🚨.view.tintColor = UIColor(red: 74/255, green: 88/255, blue: 94/255, alpha: 1)
    🚨.addCancelAction
    🚨.popoverPresentationController?.permittedArrowDirections = .up
    viewController.present(🚨)
}


func getColor() -> Int {
    let key = UserDefaults.standard.object(forKey: "Color") as? Int ?? 5
    guard key < Settings.colorsHEXs.count else {
        setInt(forKey: "Color", val: 5)
        return 5
    }
    return key
}

func setInt(forKey: String, val: Int) {
    let defaults = UserDefaults.standard
    defaults.set(val, forKey: forKey)
    defaults.synchronize()
}

func setBool(forKey: String, val: Bool) {
    let defaults = UserDefaults.standard
    defaults.set(val, forKey: forKey)
    defaults.synchronize()
}

func getInt(forKey key: String) -> Int {
    return UserDefaults.standard.object(forKey: key) as? Int ?? 0
}

func createTapBarLabel(text: String) -> UILabel {
    let label = UILabel()
    label.text = text
    label.textColor = UIColor(red: 77.0 / 255, green: 79.0 / 255, blue: 84.0 / 255, alpha: 1)
    label.sizeToFit()
    label.frame.size = CGSize(width: label.frame.size.width + 28, height: label.frame.size.height + 36)
    return label
}

// MARK: - Login and ChangePassword funcs

func animation(textfield: UITextField, duration: TimeInterval, delay: TimeInterval, const: CGFloat) {
    UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: [], animations: {
        textfield.center.x += const
    }, completion: nil)
}

/**
 Dangles textField
 - parameter textfield: Text Field to dangle
 */
func dangle(textfield: UITextField) {
    animation(textfield: textfield, duration: 0.05, delay: 0, const: 3)
    animation(textfield: textfield, duration: 0.05, delay: 0.05, const: -3)
    animation(textfield: textfield, duration: 0.04, delay: 0.1, const: 2)
    animation(textfield: textfield, duration: 0.04, delay: 0.14, const: -2)
    animation(textfield: textfield, duration: 0.03, delay: 0.18, const: 1.2)
    animation(textfield: textfield, duration: 0.03, delay: 0.21, const: -1.2)
}

func selectionFeedback() {
    if #available(iOS 10.0, *) {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

func impactFeedback() {
    if #available(iOS 10.0, *) {
        UIImpactFeedbackGenerator().impactOccurred()
    }
}

func successFeedback() {
    if #available(iOS 10.0, *) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

func errorFeedback() {
    if #available(iOS 10.0, *) {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

/// Converts date from Mail and Posts into readable expression
func cleverDate(_ date: String) -> String {
    guard let yearRange = date.range(of: "(\\d\\d\\d\\d)", options: .regularExpression),
        let year = Int(date[yearRange]),
        let monthRange = date.range(of: "(?<=.)(\\d\\d)(?=.)", options: .regularExpression),
        let month = Int(date[monthRange]),
        let dayRange = date.range(of: "(\\d\\d)(?=.)", options: .regularExpression),
        let day = Int(date[dayRange]),
        (NSCalendar.current as NSCalendar).components([.year], from: Date()).year == year else { return date }
    var monthName = ""
    switch month {
    case 1: monthName = "Янв"
    case 2: monthName = "Фев"
    case 3: monthName = "Мар"
    case 4: monthName = "Апр"
    case 5: monthName = "Мая"
    case 6: monthName = "Июн"
    case 7: monthName = "Июл"
    case 8: monthName = "Авг"
    case 9: monthName = "Сен"
    case 10: monthName = "Окт"
    case 11: monthName = "Ноя"
    case 12: monthName = "Дек"
    default: ()
    }
    return "\(day) \(monthName)"
}

struct User {
    var username: String
    var id: Int
}

func getSchedule() -> Int {
    return UserDefaults.standard.object(forKey: "Schedule") as? Int ?? 1
}

func getFirstUser() -> Int {
    return UserDefaults.standard.object(forKey: "SID0") as? Int ?? 0
}

func setFirstUser(_ user: Int) {
    let defaults = UserDefaults.standard
    defaults.set(user, forKey: "SID0")
    defaults.synchronize()
}

func setAny(forKey: String, val: Any) {
    let defaults = UserDefaults.standard
    defaults.set(val, forKey: forKey)
    defaults.synchronize()
}

func setUsers(_ users:[User]) {
    var i = 0
    for user in users {
        UserDefaults.standard.set(user.username, forKey: "User\(i)")
        UserDefaults.standard.set(user.id, forKey: "SID\(i)")
        i += 1
    }
    UserDefaults.standard.set(i, forKey: "NumberOfUsers")
    UserDefaults.standard.synchronize()
}

func getUsers() -> [User] {
    let userCount = UserDefaults.standard.object(forKey: "NumberOfUsers") as? Int ?? -1
    var result = [User]()
    var i = 0
    while i < userCount {
        let user = User(
            username: UserDefaults.standard.object(forKey: "User\(i)") as? String ?? "Ошибка",
            id: UserDefaults.standard.object(forKey: "SID\(i)") as? Int ?? 0
        )
        result.append(user)
        i += 1
    }
    return result
}

func getReloadForum() -> Bool {
    return UserDefaults.standard.object(forKey: "ReloadForum") as? Bool ?? false
}
func getReloadForumMessage() -> Bool {
    return UserDefaults.standard.object(forKey: "ReloadForumMessage") as? Bool ?? false
}

func getString(forKey: String) -> String {
    return UserDefaults.standard.string(forKey: forKey) ?? ""
}
