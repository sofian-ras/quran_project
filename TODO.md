# TODO: Optimize Memory and Add Audio Download Feature

## Memory Optimization
- [x] Modify AudioService to load only the current surah instead of preloading all 114 surahs
- [x] Implement on-demand loading for next/previous surahs
- [ ] Add caching mechanism for recently played surahs

## Audio Download Feature
- [x] Create AudioDownloadService class for managing downloads
- [x] Add download status tracking (downloaded, downloading, not downloaded)
- [x] Implement local storage for downloaded audios
- [x] Add download progress indication

## UI Updates
- [ ] Add download icon to mini audio player
- [ ] Add download icon to full player screen
- [ ] Show download status in surah selector
- [ ] Add download management screen

## Integration
- [x] Update AudioService to prefer local files over streaming
- [x] Handle offline playback when files are downloaded
- [x] Add error handling for download failures
