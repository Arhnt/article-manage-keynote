# Turning Apple Watch into Keynote Presenter using Deep Learning
## Part 1 - Data Acquisition and Analysis
### Apple Watch application
[Swift snipper for Apple Watch application](part1/InterfaceController.swift)

Full Swift project will be included in next part.

### Labeling tool
JS application used to easily navigate through data and markup snaps.
[Markup Tool](part1/markup-tool)

Start web server
```
cd part1
python -m http.server
```
Open link in browser
```
http://localhost:8000/markup-tool/
```

### Using Apple script to control keynote
Apple Script allows to control Keynote actions from external application. 
[Apple script to move to a next slide](part1/next-slide.applescript)

Try it out using `osascript`
```
osascript part1/next-slide.applescript
```