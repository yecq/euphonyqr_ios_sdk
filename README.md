# euphonyqr_ios_sdk

动听官网 http://www.euphonyqr.com</br>
动听测试服 http://sandbox.euphonyqr.com</br>

1. 准备</br>
  请和动听工作人员联系获取售前服务文档，并全部完成。如果只是想尝试一下SDK，可以跳过这一步。
2. 集成SDK</br>
  参照sdkdemo，大体业务流程是：</br>
  1）参考Appdelegate.m,在didFinishLaunchingWithOptions中初始化sdk，传入的参数有</br>
  (a) appkey | string | 注册了动听帐号后可以在个人中心->应用管理中查看appkey</br>
  (b) isSandbox | bool | appkey是官网的填false，是测试服的填true</br>
  (c) tokenURL | string | 请自行布署一个后端服务器用来获取token，访问动听api需要token， 具体请见 https://github.com/haoboyang/qs_wx_token</br>
  2）设置userID或phoneNumber，做为数据分析标识通过动听后台API返回，可选。</br>
  3）参考ViewController.m中的doTest方法，调用detect，等待返回结果。如果想要反复检测，可以在检测回调后立即给主线程发消息，再次调用detect。可选的参数有customData(可以通过动听后台API加上requestID查询返回)</br>
  4 ) 返回结果为^(float dB, NSDictionary * jsonResp, NSError * err)</br>
    (a) dB表示录音的分贝数，一般-90以上信号质量较好，-120及以下基本为无信号</br>
    (b) err为出错说明信息，没有错误时为nil</br>
    (c) jsonResp为返回数据，没有结果或出错是为nil，格式为：</br>
    {</br>
        "reqid":"xxxxx", |动听返回的requestID，可用于查询</br>
        "count":2, | 有效结果的总数(result数组大小）</br>
        "allTags":["tag1","tag2","tag3"], | 所有有效结果中的tags的集合</br></br>
        "result":[ | 所有有效的结果，并且按power(音量分贝)排序</br>
            {</br>
                "channel":3, | 信道号：从0开始</br>
                "power":-89, | 此信道的分贝数</br>
                "tags":["tag1","tag2"] | 检测返回的结果，可以有多个字符串</br>
            },</br>
            {</br>
                "channel":1,</br>
                "power":-102,</br>
                "tags":["tag3"]</br>
            },</br>
        ],</br></br>
        "sortByPowerResult":[ |包含有效和无效的结果，按power(音量分贝)排序</br>
            {</br>
                "channel":3,</br>
                "power":-89,</br>
                "tags":["tag1","tag2"]</br>
            },</br>
            {</br>
                "channel":1,</br>
                "power":-102,</br>
                "tags":["tag3"]</br>
            },</br>
            {</br>
                "channel":0,</br>
                "power":-108,</br>
                "tags":[]</br>
            },</br>
            {</br>
                "channel":2,</br>
                "power":-120,</br>
                "tags":[]</br>
            },</br>
        ],</br></br>
        "rawResult":[|包含有效和无效的结果，按channel递增</br>
            {</br>
                "channel":0,</br>
                "power":-108,</br>
                "tags":[]</br>
            },</br>
            {</br>
                "channel":1,</br>
                "power":-102,</br>
                "tags":["tag3"]</br>
            },</br>
            {</br>
                "channel":2,</br>
                "power":-120,</br>
                "tags":[]</br>
            },</br>
            {</br>
                "channel":3,</br>
                "power":-89,</br>
                "tags":["tag1","tag2"]</br>
            },</br>
        ],</br></br>
    }

3. 测试</br>
  从动听工作人员处取得测试音频或测试设备，测试音频请用mac电脑（IBM，联想，三星电脑不行）或专业音响，蓝牙音响播放，测试设备使用方法请咨询动听工作人员。
4. 注意事项和常见问题：</br>
  1）初始化请尽可能的提前，建议把BuyfullSDK做为整个APP生命周期中都存在的组件</br>
  2）请分清楚APPKEY和SECKEY是在动听官网 http://www.euphonyqr.com申请的还是在动听测试服 http://sandbox.euphonyqr.com申请的。线下店帐号和APP帐号都要在同一平台上申请才能互相操作。</br>
  4）请确保网络通畅并且可以连接外网。</br>
  5）开发人员需要自行申请麦克风权限，同时建议在APPSTORE提交审合时动态暂时关闭检测功能以免解释麻烦。</br>
  6 ) 请查看一下AppDelegate和ViewController中的注释。</br>
  7 ) 请至少在APP帐号下购买一个渠道后再进行测试，并且请在渠道中自行设定，自行设定，自行设定（重要的事情说三遍）识别结果，可以为任何字符串包括JSON。</br>
  
  
5. API说明</br>
  请查看一下buyfullSDK.h中的方法注释
  
  
  有疑问请联系QQ:55489181