---
title: "EOS in ReactNative"
date: 2018-11-10
draft: false
---
# EOS in ReactNative

最近遇到了要在 ReactNative 中使用 eosjs 的需求，官方只提供了 node 环境（CommonJS）和 browser 环境（UMD）的包，而 ReactNative 的模块系统则是 node-haste，一个类似 CommonJS 的模块系统。写篇文章记录一下问题的解决过程，文章内不再赘述 CommonJS AMD UMD 等模块系统的区别和应用。

### 背景

EOS，可以理解为 Enterprise Operation System，即为商用分布式应用设计的一款区块链操作系统。EOS 是引入的一种新的区块链架构，旨在实现分布式应用的性能扩展，被称为区块链 3.0。

EOS 的核心组成是 nodeos 和 cleos。nodeos 是运行在服务端的区块链节点组件，是 EOSIO 系统的核心进程，可以通过它运行一个节点。nodeos 运行后会暴露出一系列 http 接口，官方称之为 rpc API，可以通过其进行查询及 push transaction 等操作。cleos 是对链进行操作的命令行工具，本质上也是在调用 nodeos 暴露出来的 API，但功能更丰富，可以进行管理钱包、创建账户等敏感性操作。cleos 可以通过指定链的 API 地址来对不同的链进行操作，这更说明 cleos 本质上调用了 nodeos 暴露的 API。

CRUD，除了检索外，所有涉及状态的变更都是由 action 完成的，action 和 contract 在 EOS 中发挥着重要的角色。DAPP 的重中之重是逻辑的编织和逻辑的调用，前者通过编写 contract 丰富 action 的种类完成，后者通过在 DAPP 的 client 使用 EOS 的 SDK 发起各种 action 完成。

### EOS SDK

目前，EOS 官方提供的支持度最高的是 JavaScript 版本的 SDK，eosjs。eosjs 主要由两个子包，eosjs-api 和 eosjs-ecc 组成，eosjs-api 负责 http api 调用的部分 (主要是 GET 的部分)，eosjs-ecc 负责加密和签名的部分。NPM 仓库中的 eosjs 只能在 node 环境中使用，它使用了 CommonJS 格式，而且它的核心加密模块 eosjs-ecc 使用了大量 node 的 built-in module，例如 buffer、assert 和 crypto。所以不经过处理，eosjs 只能在 node 环境中运行。

然而 eosjs 作为开发 DAPP 和钱包的必需 sdk，为保证用户的数据未被篡改，私钥未被窃取，eosjs 一定要有在客户端中运行的能力。因次随着大量 web 开发者向 eosjs 发出 feature request，eosjs 终于支持了在浏览器中运行，查看其 `package.json`:

```javascript
  "scripts": {
    "build_browser": "browserify -o lib/eos.js -s Eos lib/index.js",
  }
```

其思路大致是利用 `browserify` 将可以在 node 环境中运行 CommonJS 包编译成可以在浏览器环境中运行的 UMD 包（当然，UMD 包也可以在 node 环境中使用，它同时兼容 AMD 和 CommonJS）。这行命令意思是以 `lib/index.js` 为入口文件，编译生成 `lib/eosjs`, 通过执行 `browserify -h`:

```javascript
$ browserify -h
Usage: browserify [entry files] {OPTIONS}

Standard Options:
  --standalone -s  Generate a UMD bundle for the supplied export name.
                   This bundle works with other module systems and sets the name
                   given as a window global if no module system is found.
```

可以了解到 `-s` 命令指定了模块格式为 UMD，模块名为 `Eos`。

### 尝试在 ReactNative 中使用 eosjs

在正式讨论 ReactNative 中运行 eosjs 前，先聊几个点：

1.`browserify` 作为模块打包器，它可以将 node 的 built-in module 和 native module 替换成 polyfill，以让程序在浏览器中得以运行。打包后，所有模块用 key 为 module id 的 plain object 存储，每个模块变成了形如

```javascript
function (require, module, exports) {...}
```

的函数，`browserify` 保留了 `require` 的函数名，并且重写了 `require` 函数：

```javascript
// 需要上下文
function (r) {
          var n = e[i][1][r];
          return o(n || r)
}
```

原来模块代码中的 `require` 不再调用 node 内置的 `require` 函数，而是调用 `browserify` 实现的 `require` 函数。

举个例子：

```javascript
// src/foo.js
var crypto = require('crypto')
module.exports = {
  hash: crypto.createHash
}

// src/index.js
var hash = require('./foo').hash

module.exports = {
  content: hash('md5').update('jader').digest('hex')
}

```

执行 ` browserify index.js -o dist/index.js`

```javascript
// dist/index.js
// ... 2 万多行的 polyfill
},{}],154:[function(require,module,exports){
var crypto = require('crypto')

module.exports = {
  hash: crypto.createHash
}
},{"crypto":55}],155:[function(require,module,exports){
var hash = require('./foo').hash

module.exports = {
  content: hash('md5').update('jader').digest('hex')
}
},{"./foo":154}]},{},[155])(155)
});
```

可以看出，`browserify` 生成的模块依赖还是比较清晰的，一个 plain object，key 是 module id, value 是一个数组，数组第一位是用函数包起来的元模块代码，调用时传入 `browserify` 自己实现的 `require` 函数。数组第二位记录该模块的依赖模块名称及 id，自实现的 `require` 函数会根据这个字段去加载对应的模块代码。

2.ReactNative 的打包工具既不是 webpack，也不是 gulp，而是自己造的轮子——metro。ReactNative 以 metro 作为打包工具，以 node-haste 作为模块加载方式。

3.ReactNative 不支持动态 require。何为动态 require？

```javascript
// 不支持
const foo = './src/index.html'
const index = require(foo)

// 不支持
const foo = './src'
const index = require(`${foo}/index.html`)

// 支持
const index = require('./src/index.html')
```

在 ReactNative 中，打包发生在运行前，而不是运行时。packager 将代码视为文本进行静态分析，并调用 metro 自己实现的 `require` 函数去处理依赖，因此 `require` 函数自然无法理解变量参数。



综合以上几点，聊聊我对 eosjs 的使用过程。

一开始，

```javascript
yarn add eosjs

import Eos from 'eosjs'

react-native run-ios

// 出错
unable to resolve module 'crypto' from ...
```

想了下，很明显是因为 eosjs 引用了 node built-in module，所以不能被解析打包。去 Github issue 区查了下相关问题，发现 eosjs 对浏览器和 ReactNative 的支持还不完善。当时业务工期比较近，而 eosjs-api 不存在平台局限性又能满足业务需要，所以直接用了这个包。

后来，业务需要用到 eosjs-ecc 的部分，又重新去思考如何在 ReactNative 中使用 eosjs。秉承着 “not invented here” 和“不重复造轮子的原则”，我先去社区里找解决方案。巧的是，在这一段时间里，eosjs 出现了 broken change，版本号从 16.0.9 跳到了 20.0.0，而且就在 1 天前社区有人 fork 了新版本的 eosjs-ecc 和 eosjs 进行修改，提供了 eosjs-ecc-rn 和 eosjs-rn 两个 ReactNative 专用包。查 git log 得知，他将两个包中依赖的 node built-in module 替换成了第三方的 polyfill，简单粗暴。开心地试一下，结果报错：

```javascript
Reference Error: Proxy is not defined
```

很明显，这是因为 ReactNative 的 runtime 不支持 Proxy，而且 fork 代码的那个哥们还没来得及踩这个坑。

咋办？翻源码。

```javascript
...
// The size, in bytes, of a word.
var word_size = 4;
...
var X = new Array(t).fill(undefined).map(function(_, i) {
    return new Proxy(new DataView(padded,i * block_size,block_size),{
        get: function get(block_view, j) {
            return block_view.getUint32(j * word_size, true // Little-endian
            );
        }
    });
});
...
// Message word selectors.
var r = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8, 3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12, 1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2, 4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13];
...
RIPEMD160.add_modulo32(A, RIPEMD160.f(j, B, C, D), X[i][r[j]], RIPEMD160.K(j))

```

所有相关代码都摘在上面了，幸运的是，用到 Proxy 的地方只有一处，而且只拦截了 get 用来在读取值时做实时计算。让人不得不吐槽的是，作为一个底层计算库，这么一个简单的功能明明可以用预计算或者 defineProperty 实现，为什么非要用无法被编译、没有完美 polyfill 的 Proxy 实现呢？

好吧，我来改。

```javascript
var X = new Array(t).fill(undefined).map(function(_, i) {
    // dataView 只提供 getUint32 方法
    var dataView = new DataView(padded,i * block_size,block_size)
    return Array.from({
        length: 16
    }, (_,k)=>dataView.getUint32(Number(k) * word_size, true))
});

```

本地改完试一下，编译打包运行，没问题，顺手发了个 Pull Request。第二天起床一看，被顺顺利利 merge 了，还被感谢了一番，开心 XD。

### 尾注

其实这段过程也蛮曲折的，为了行文流畅，我把费尽心思调研出来的要点放在了前面。其实社区中 ReactNative Packager (即 Metro) 和 node-haste 的资料并不多，EOS 的 ReactNative 社区也可谓是贫瘠，很多坑需要自己去踩。比如说最后 Proxy 的问题，开发阶段使用模拟器还好好的，打包后在真机运行时却会白屏，查看错误信息才发现是 Proxy 的问题，根源是在真机中，代码运行在 JavaScriptCore 中，也就是 Safari 和国产一众小程序在 iOS 的引擎，而开发调试中，代码运行在 blink/v8 中，Proxy 又是不能被编译和没有完美 polyfill 的，所以 ReactNative 并不支持 Proxy，我查看了 JavaScriptCore 的相关 Proxy feature request issue，发现 JavaScriptCore 对移动端适配的版本对 Proxy 的支持还是遥遥无期，也就是说，国产一众小程序也无法使用 Proxy 了。社区中 Proxy polyfill 的最好版本是 [GoogleChrome/proxy-polyfill](https://github.com/GoogleChrome/proxy-polyfill)，但是它对数组的处理跟原生的 Proxy 相比还是有差异，我曾尝试使用这一版本的 polyfill，结果以失败告终。

还有一点有趣的是，在最新版本的 ReactNative 中，新的 metro 可以对 browserify 输出的文件进行正确的解析和打包，不会发生怪异的 ` require` 替换。但是 browserify 对一些 node built-in/native modules 的 polyfill 会嫌弃 JavaScriptCore 支持的特性太少而无法运行，又是一记讽刺。metro 的提升缓慢，又不与 webpack 共享生态，node-haste 业已处于半废弃的状态，希望 ReactNative 的团队在将来的重构中重新思考和设计模块加载和打包方式。