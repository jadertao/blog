---
title: "TypeScript 中继承的实现"
date: 2018-12-19
draft: false
---
# TypeScript 中继承的实现

TL;DR

末尾有总结。



这篇文章我会探究 TypeScript 中 extends 的实现机理。

在 JavaScript 中实现继承是一个比较古老的话题，也是垃圾文章的重灾区。诚然现如今我们可以在 tsc 加持的 TypeScript 和 babel 加持的 ES Next 中简单地使用 class extends 关键字实现继承，但理解如何在 ES5 中如何使用 `prototype` 与 `[[Prototype]]`] 实现继承更能增加自己对 JavaScript 较细粒度上的理解。

广泛使用的方案其正确性也毋庸置疑，因此本文将以 TypeScript class extends 转换成的 ES5 代码作为重点分析。

> 之所以不分析 babel 的方案只是因为笔者更喜欢 TypeScript。

## 背景

面对对象编程（Object-oriented programming）是一种有对象概念的编程范式，也是一种程序开发的抽象方针。

它是一种范式，体现在某个具体的语言上则有不同的风格，比如说 Java、C++、Python 中的基于类（class）的面向对象风格，以及  JavaScript、Lua、Self 中的基于原型（prototype）的面向对象风格。

> 这里多说一句，JavaScript 的设计主要受到了 Self 和 Scheme 的影响，Self 语言是在 SmallTalk 语言的基础上发展而来的，StrongTalk 是 SmallTalk 的高性能 VM，而 JavaScript 性能最好的引擎 V8 又是吸收了 HotSpot 和 StrongTalk 的精华，V8 的仓库里至今仍有 StrongTalk 的 [license](https://github.com/v8/v8/blob/master/LICENSE.strongtalk)。

## 原料

把简单的 TypeScript 继承语句用 tsc 编译成 ES5，[参考这里](http://www.typescriptlang.org/play/index.html#src=class%20Foo%20%7B%7D%0D%0Aclass%20Bar%20extends%20Foo%20%7B%7D)。

```javascript
// TypeScript
class Foo {
    static value: number = 1
    public foo: number
    constructor() {
        this.foo = 1
    }
    add1(v: number): number {
        return 1 + v
    }
}
class Bar extends Foo {
    static subValue: number = 2
    constructor() {
        super()
        console.log(this.foo);
    }
}

// -------
// TSC 编译
// -------

// ES5
var __extends = (this && this.__extends) || (function () {
    var extendStatics = function (d, b) {
        extendStatics = Object.setPrototypeOf ||
            ({__proto__: [] } instanceof Array && function (d, b) { d.__proto__ = b; }) ||
            function (d, b) { for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p]; };
        return extendStatics(d, b);
    };
    return function (d, b) {
        extendStatics(d, b);
        function __() { this.constructor = d;}
        d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
    };
})();
var Foo = /** @class */ (function () {
    function Foo() {
        this.foo = 1;
    }
    Foo.prototype.add1 = function (v) {
        return 1 + v;
    };
    Foo.value = 1;
    return Foo;
}());
var Bar = /** @class */ (function (_super) {
    __extends(Bar, _super);
    function Bar() {
        var _this = _super.call(this) || this;
        console.log(_this.foo);
        return _this;
    }
    Bar.subValue = 2;
    return Bar;
}(Foo));
```

好了，开始对代码的分析，step by step，statement bt statement，expression by expression。

## 源码分析

类的属性和方法分两部分，静态属性和方法以及成员属性和方法。静态属性和方法体现为类构造函数的属性及方法，成员属性和方法体现为类构造函数的 `prototype` 对象的属性及方法。

### extends 的实现

顶层声明的 `__extends` 函数毫无疑问是 `extends` 的 polyfill 实现。

#### 一、

```javascript
(this && this.__extends) || (function () {...})()
```

这里是防止 `__extends` 函数的重复声明。`||` 左侧判断当前上下文是否存在及当前上下文中是否有 `__extends` 函数。若皆满足条件，则直接返回 `this.extends`；若不满足，则重新声明该函数，`||` 右边的函数即其函数体。

- this 是谁？

在 JavaScript 中，除非特殊指定，this 的指向的 `context object` 由调用时的对象和上下文决定，表现与 dynamic scope 相似。（而闭包的建立是 lexical scope/static scope）

- 为什么先要判断 this 是否存在？

严格模式下，this 若指向全局执行上下文，则会被置为 undefined。

```javascript
(function(){'use strict';console.log(this);})() // undefined
(function(){console.log(this);})()              // Window
```

- this.__extends 有问题吗？

有。如果 this 环境对象中已有 `__extends` 变量或属性，且其值是 Truthy 的，那 `__extends` 会被错误地赋值。不过绝大多数情况下 TypeScript 会把控所有代码细节，不会出现冗余的 `__extends` 变量或属性。

#### 二、

```javascript
(function () {
  var extendStatics = function (d, b) {
      extendStatics = Object.setPrototypeOf ||
          ({__proto__: [] } instanceof Array && function (d, b) { d.__proto__ = b; }) ||
          function (d, b) { for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p]; };
      return extendStatics(d, b);
  };

  // 返回匿名函数，赋给 __extends，为方便表述，记该匿名函数为 A 函数
  return function (d, b) {
      extendStatics(d, b);
      function __() { this.constructor = d;}
      d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
  };
})()
```

嗯。。。这段代码读起来没那么复杂，但是讲解起来比较麻烦，我们来慢慢看。

主要有 10 点：

<h4> 第 0 点 </h4>

最外层是一个 IIFE（Immediately Invoked Function Expression，即时调用的函数表达式），函数体内声明了 `extendStatics` 函数，根据名字来看是用来继承 class 的静态属性和方法。

```javascript
var extendStatics = function (d, b) {
    extendStatics = Object.setPrototypeOf ||
        ({__proto__: [] } instanceof Array && function (d, b) { d.__proto__ = b; }) ||
        function (d, b) { for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p]; };
    return extendStatics(d, b);
};
```

这是一个 `function expression`，声明变量 `extendStatics` 为一个函数，参数 d 为子类，b 为父类。

函数体中将 `extendStatics` 重新赋值为一个新的函数 (该函数将子类的 `[[Prototype]]` 赋值为父类构造函数) 并随后调用了一次，重新赋值的目的：

- 这其实是一个用完即毁的初始化函数，一方面实现了 `extendStatics` 的初始化，且将初始化语句限制在函数作用域内。另一方面只要调用一次后，变量 `extendStatics` 被指向了另外一个函数引用，没有变量再保持对原来初始化函数的引用，这样无论是引用计数还是标记清除，失去了可达性的初始化函数所占的内存可以被引擎快速回收。

来具体看一下初始化过程：

<1> 方案一，如果当前环境支持 `Object.setPrototypeOf` 则直接将其赋给 `extendStatics`，否则进行下一步判断；

<2> 方案二，判断 `({ __proto__: [] }) instanceof Array`，如果 `true`，将 `function (d, b) { d.__proto__ = b; })` 赋给 `extendStatics`，否则进行下一步判断；

这里以 `V instanceof F` 为例，额外讲一下 `instanceof`，不做实验，一切以标准、规范和引擎的实现为第一优先级：

> [ECMA-262 标准介绍 instanceof 操作符](http://ecma-international.org/ecma-262/5.1/#sec-11.8.6)： `instanceof` 操作符会返回 `B` 内部 `[[HasInstance]]` 方法以 `A` 为参数的调用结果；

> ECMA-262 标准介绍 `HasInstance`：(1)[12.10.4Runtime Semantics: InstanceofOperator ( V, target )](http://ecma-international.org/ecma-262/5.1/#sec-15.3.5.3) ，(2)[19.2.3.6Function.prototype [ @@hasInstance ] ( V )](http://www.ecma-international.org/ecma-262/#sec-function.prototype-@@hasinstance) ，(3)[6.1.5.1 Well-Known Symbols 表格的第二行](http://www.ecma-international.org/ecma-262/#sec-well-known-symbols)；

> V8 对  [ES6 #sec-function.prototype-@@hasinstance 的实现](https://github.com/v8/v8/blob/3b0f8243d00f4055456cb21d2a5dbe0fe85c4bd9/src/builtins/builtins-function-gen.cc#L197) 和对 [OrdinaryHasInstance](https://github.com/v8/v8/blob/master/src/objects.cc#L787) 的实现；

总结一下，求值表达式 `V instanceof F` 时，会计算 `F` 内部 `[[HasInstance]]` 方法以 `V` 为参数的调用结果，`F` 内部 `[[HasInstance]]` 方法是通过 `Symbol.hasInstance` 部署实现的，所以 `V instanceof F` 等同于调用 `F[Symbol.hasInstance](V)`。

`Symbol.hasInstance` 会按固定的顺序检测：

① 如果 `V` 不是一个 `object`，返回 `false`;

② 计 `O` 为 `F.prototype`；

③ 如果 `typeof O !== 'object'`，抛出 **TypeError** 异常；

④ 循环：a，令 `V` 值为 `V` 的 `[[Prototype]]` 属性值，即 `V = V.__proto__`；b，如果 `V === null`，返回 `false`；c，如果 `O` 和 `V` 是对同一对象的引用，返回 `true`.

ok，讲解完成，我们再回到 `({__proto__: [] }) instanceof Array`，按照上面的逻辑显然：

```javascript
Array[Symbol.hasInstance]({__proto__:[]})
```

即计算

```javascript
({__proto__: [] }).__proto__ === Array.prototype // false
```

这一步，未满足跳出循环条件，进入下一步循环，计算

```javascript
({__proto__: [] }).__proto__.__proto__ === Array.prototype // true
```

返回 `true`，循环结束，计算完成。

结束 `instanceof` 的讲解，让我们把思绪拉回至初始化函数的步骤 <2>:

```javascript
 ({__proto__: [] } instanceof Array && function (d, b) { d.__proto__ = b; })
```

这一步是为了检测当前环境是否允许直接通过字面量直接设置对象的 `__proty__ `aka `[[Prototype]]`，如果允许，则将 `extendsStatics` 直接定义为右侧函数，该函数将子类 `__proto__` 指向父类的构造函数；如不允许，进入最终方案。

<3> 最终方案，将静态属性一一复制过去，用 `hasOwnProperty` 过滤掉原型链（`__proto__`）上的属性。

> 需要注意的是，前两种方案都是把静态属性所在的对象（即父类的构造函数）委托至子类（的构造函数的 `__proto__` 属性）上，而第三种方案是把父类本身的构造函数上的静态属性一一复制到子类的构造函数本身。

<h4> 第 10 点 </h4>

继承函数本体

```javascript
  // 返回匿名函数，赋给 __extends，为方便表述，记该匿名函数为 A 函数
  return function (d, b) {
      extendStatics(d, b);
      function __() { this.constructor = d;}
      d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
  };
```

这个函数主要实现了：调用 `extendStatics` 继承静态属性，然后在父类为 `null` 时直接使用 `Object.create` 实现继承，在父类不为 `null` 时使用空函数对象 `__` 作为中介继承成员属性，并修正 `constructor`。

为什么要用空函数对象做中介？

```javascript
// 有中介
d.prototype -> new __()
(new __()).__proto__ -> __.prototype -> b.prototype
即实现了 d.prototype.__proto__ -> __.prototype -> b.prototype

// 无中介 (还有其他无中介的方法，请参考阮一峰的文章，此处只举例最基础的一种)
d.prototype -> new b()
(new b()).__proto__ -> b.prototype
即实现了 d.prototype.__proto__ -> b.prototype

```

首先两者都可以实现对成员属性和函数的继承，且父类 `prototype` 一旦更新，子类都会即时受到影响。
有中介的 ** 优势 ** 在于：只需 new 空函数，不需 new 父类，一定程度省了内存。

不过无论是那种方式，只要直接修改子类的 `prototype` 引用都会影响 `constructor`，对语义和 JS 的一些内部实现（不包括 `instanceof`，见上）产生干扰。因此需要 `d.prototype.constructor = d`，这就是 `this.constructor = d;` 起的作用。

#### 三、

至此 `__extends` 函数已分析完，来看一下使用：

```javascript
var Foo = /** @class */ (function () {
    function Foo() {
        this.foo = 1;
    }
    Foo.prototype.add1 = function (v) {
        return 1 + v;
    };
    Foo.value = 1;
    return Foo;
}());
var Bar = /** @class */ (function (_super) {
    __extends(Bar, _super);
    function Bar() {
        var _this = _super.call(this) || this;
        console.log(_this.foo);
        return _this;
    }
    Bar.subValue = 2;
    return Bar;
}(Foo));
```

发现除了先调用 `__extends` 外，还在子类的构造函数内调用父类的构造函数来复用父类的一些逻辑（事实上，如果不调用 `super`，TypeScript 会直接在静态分析时抛出错误：` 派生类的构造函数必须包含 "super" 调用。`）。这里也处理了构造函数的返回值问题。

## 总结

### 复用：

1. 静态属性及方法

   - ` Object.setPrototypeOf`

   - `function (d, b) { d.__proto__ = b; })`

   - `function (d, b) { for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p]; }`

     依次优雅降级。

2. 成员属性及方法

   通过一个空函数对象增加了一层原型链委托节点。

3. 父类构造函数

   在声明 `constructor` 的子类，TypeScript 会强制其调用 `super` 来调用父类构造函数的逻辑。

### 需要注意的点

1. 更改 `prototype` 的引用需要修正 `constructor`。

2. 原则上 class 一旦被声明就不应该被增删属性，TypeScript 没有做出源码级别的限制，但是会在静态分析时直接报错。限制了灵活性，增加了规范性，各有利弊。

### 评价：精巧而严谨

大量使用 IIFE 限制一些语句及变量的生效范围

大量使用括号，&&，||，逗号运算符精简表达式语句

精致的用后即焚初始化函数，减少了变量和内存的冗余

多方案的替换使程序在不同环境中保持健壮