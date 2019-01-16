---
title: "关于闭包(上篇)"
date: 2018-08-01
draft: false
---

为什么写这篇文章：网上关于闭包的解释五花八门，很多人自己往往也未清楚闭包，就尝试用蹩脚的语言去描述它，而闭包是一个相对抽象的、跨越语言的概念，网上的这些说法往往夹带了JS的私货。所以本篇是我整理的三点关于闭包的权威资料，并没有自己的私货。下面的资料有一些有趣的分歧，如果你发现了并且有兴趣与我探讨一下，欢迎联系我。

### 一、MDN

英文版：

Closures are functions that refer to independent (free) variables (variables that are used locally, but defined in an enclosing scope). In other words, these functions 'remember' the environment in which they were created.

中文版：

Closures (闭包)是使用被作用域封闭的变量，函数，闭包等执行的一个函数的作用域。通常我们用和其相应的函数来指代这些作用域。(可以访问独立数据的函数)

闭包是指这样的作用域，它包含有一个函数，这个函数可以调用被这个作用域所*封闭*的变量、函数或者闭包等内容。通常我们通过闭包所对应的函数来获得对闭包的访问。

### 二、IBMdeveloperworks

闭包并不是什么新奇的概念，它早在高级语言开始发展的年代就产生了。闭包（Closure）是词法闭包（Lexical Closure）的简称。对闭包的具体定义有很多种说法，这些说法大体可以分为两类：

一种说法认为闭包是符合一定条件的函数，比如参考资源中这样定义闭包：闭包是在其词法上下文中引用了自由变量(注1)的函数。

另一种说法认为闭包是由函数和与其相关的引用环境组合而成的实体。比如参考资源中就有这样的的定义：在实现深约束(注2)时，需要创建一个能显式表示引用环境的东西，并将它与相关的子程序捆绑在一起，这样捆绑起来的整体被称为闭包。

这两种定义在某种意义上是对立的，一个认为闭包是函数，另一个认为闭包是函数和引用环境组成的整体。虽然有些咬文嚼字，但可以肯定第二种说法更确切。闭包只是在形式和表现上像函数，但实际上不是函数。函数是一些可执行的代码，这些代码在函数被定义后就确定了，不会在执行时发生变化，所以一个函数只有一个实例。闭包在运行时可以有多个实例，不同的引用环境和相同的函数组合可以产生不同的实例。所谓引用环境是指在程序执行中的某个点所有处于活跃状态的约束所组成的集合。其中的约束是指一个变量的名字和其所代表的对象之间的联系。那么为什么要把引用环境与函数组合起来呢？这主要是因为在支持嵌套作用域的语言中，有时不能简单直接地确定函数的引用环境。这样的语言一般具有这样的特性：

函数是一阶值（First-class value），即函数可以作为另一个函数的返回值或参数，还可以作为一个变量的值。

函数可以嵌套定义，即在一个函数内部可以定义另一个函数。

### 三丶历史上闭包的第一次定义

闭包这个概念第一次出现在1964年的《The Computer Journal》上，由P. J. Landin在《The mechanical evaluation of expressions》一文中提出了applicative expression和closure的概念。

文中AE的概念定义如下：

>We are, therefore, interested in a class of expressions about any one of which it is appropriate to ask the following questions:
>
>Q1. Is it an identifier? If so, what identifier?
>
>Q2. Is it a λ-expression? If so, what identifier or identifiers constitute its bound variable part and in what arrangement? Also what is the expression constituting its λ-body?
>
>Q3. Is it an operator/operand combination? If so, what is the expression constituting its operator? Also what is the expression constituting its operand?
>
>We call these expressions applicative expressions (AEs).

在AE的基础上，闭包定义为:

>Also we represent the value of a λ-expression by a bundle of information called a "closure", comprising the λ-expression and the environment relative to which it was evaluated. We must therefore arrange that such a bundle is correctly interpreted whenever it has to be applied to some argument. More precisely:
>
>a closure has an environment part which is a list whose two items are:
>
>(1) an environment
>
>(2) an identifier or list of identifiers
>
>and a control part which consists of a list whose sole item is an AE.


### 结语
本篇中一共摘取了三点资料，前两点中闭包都是跟JS有少许混杂的，或者说跟lexical scope(词法作用域)少许混杂的。想要认识闭包的本质，还需要理解提出闭包的这篇的论文。所以下篇我会研读一下《The mechanical evaluation of expressions》中纯粹的 Closure，敬请期待。
