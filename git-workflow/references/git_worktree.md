Git worktree：让多个 AI agent 并行工作而不互相冲突的基础
并行运行时，你的 agent 会互相覆盖对方的工作。Git worktree 用两条命令就能解决。这篇文章告诉你怎么用。

2026年6月4日
你在同一个仓库上启动了两个 agent。一个在改 package.json，另一个也在改。三十秒后，你的代码变成了谁都没法合并的状态。

这不是 agent 的 bug，而是因为它们都在同一个文件夹里干活。

解决办法是一个 Git 已经支持多年、却几乎没人用的工具：git worktree。

问题所在：3 个 agent，1 个仓库，根本没法合并
一个普通的 Git 仓库就是一个文件夹，同一时间只能签出一个分支。你在 main 上工作，切换分支时整个文件夹都会跟着变。

现在往这个文件夹里塞进三个自主 agent。它们会同时写文件。Agent A 创建了一个文件，agent B 跑了个 git checkout 想从干净状态开始，结果把 A 正在做的工作全冲掉了。最后你得到的是一堆写了一半的文件、被搞乱的索引，以及一堆冲突，解起来比你自己写代码还费劲。

只有 agent 之间互不干扰，并行才能真正帮你省时间。

git worktree 是什么
worktree 就是挂在同一个仓库上的第二个工作文件夹。

历史相同、远程相同，但每个 worktree 都签出自己的分支，磁盘上也有自己的一套文件。你可以同时摆五个，每个在不同的分支上，互不打扰。

一个 .git，多个工作区。就这么简单。

实战：每个 agent 一个 worktree
下面是具体做法。在你的仓库里执行：

git worktree add ../project-auth -b feature/auth
git worktree add ../project-billing -b feature/billing
git worktree add ../project-export -b feature/export
你刚刚创建了三个文件夹，每个都在自己的分支上。然后在每个里启动一个 agent：

cd ../project-auth && claude
cd ../project-billing && codex
每个 agent 都有自己的文件夹、自己的分支、自己的文件。auth agent 永远看不到 billing agent 在干什么。不可能撞车。

某个功能做好后，你审查它的分支然后合并。接着清理：

git worktree remove ../project-auth
文件夹没了，分支还留在你的历史里。干净利落。

需要知道的 3 个坑
第一个坑：共享的中心文件。如果两个功能都得动同一个 routes.ts 或同一个数据库 schema，worktree 救不了你，合并的时候照样冲突。一旦某个 agent 碰了大家共用的文件，其他 agent 就得等，或者绕着走。

第二个坑：分支跑偏。你的 agent 在干活的同时，main 也在往前走。三天后你的分支已经落后一截，合并起来就很痛苦。要么趁早、勤快地 rebase，要么把每次会话控制得短一点。

第三个坑：忘了清理。每个 worktree 都是磁盘上真实存在的文件夹。一天开十个又不清理，你的父目录很快就乱得没法看了。git worktree list 能列出还留着哪些，git worktree prune 能清掉已经失效的。

真正的问题：谁来盯着这五个文件夹？
worktree 解决的是文件冲突，但解决不了你的心智负担。

你有五个文件夹、五个 agent、五个终端。哪个在等你审查？哪个十分钟前就跑完了、而你当时正看着别处？哪个崩了？

如果你一直待在终端里，这就是"每个 agent 一个 worktree"这套做法的天花板。技术上的冲突你解决了，但要盯的窗口也翻了好几倍。

AgentsRoom 把每个 agent 放到一块独立的卡片上，带着它的状态和颜色，不管它跑在哪个 worktree 里。某个 agent 一旦在等你，它就会变红并提醒你。想了解叠加在 worktree 之上的完整方法，读一读如何并行运行 3 到 8 个 agent 而不手忙脚乱。

核心要点
一个 agent，一个 worktree，一个分支。这就是认真做多 agent 工作的基本规则。

命令三行就写完，好处立竿见影：你的 agent 不再互相覆盖。再加上一个能告诉你哪个 agent 需要你的视图，你就真的能同时扛住五件事，而不至于把自己逼疯。
