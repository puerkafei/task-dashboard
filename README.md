# 曹操团队 · 任务监控仪表盘

团队任务执行状态实时监控面板，点开即看。

## 功能

- **进度圆环** — 任务完成百分比一目了然
- **流程图** — 从上到下展示每个环节，颜色区分状态（绿=完成，蓝=进行中，红=异常，灰=待开始）
- **详细记录** — 点击任一环节查看：使用工具、工作内容、是否汇报、卡点/报错详情

## 在线访问

> 部署于 GitHub Pages  
> **URL：** [https://puerkafei.github.io/task-dashboard/](https://puerkafei.github.io/task-dashboard/)

## 本地使用

直接打开 `index.html` 即可查看（内置离线数据）。

## 数据更新

各环节的状态数据存储在 `data/status.json` 中。每次任务状态变更后，各 Agent 须同步更新此文件并推送至 GitHub。

## 技术栈

纯静态 HTML + CSS + JS，零依赖。自动每 30 秒刷新数据。
