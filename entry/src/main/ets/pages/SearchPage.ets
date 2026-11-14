import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { SongItem, MusicPlaylistRespData } from '../viewmodles/commons'
import { MUSIC_free_list_API } from '../apis'
import { playerManager } from '../utils/PlayerManager'
import { StorageManager } from '../utils/StorageManager'

const HISTORY_KEY = 'search_history'

@HMRouter({ pageUrl: 'search' })
@Entry
@Component
export struct SearchPage {
  @State keyword: string = ''
  @State inputText: string = ''
  @State results: SongItem[] = []
  @State isLoading: boolean = false
  @State history: string[] = []

  aboutToAppear() {
    this.history = StorageManager.getStringArray(HISTORY_KEY)
  }

  private persistHistory() {
    StorageManager.putStringArray(HISTORY_KEY, this.history)
  }

  private addHistory(kw: string) {
    this.history = this.history.filter((k: string) => k !== kw)
    this.history.unshift(kw)
    if (this.history.length > 10) {
      this.history = this.history.slice(0, 10)
    }
    this.persistHistory()
  }

  private removeHistory(kw: string) {
    this.history = this.history.filter((k: string) => k !== kw)
    this.persistHistory()
  }

  private clearHistory() {
    this.history = []
    this.persistHistory()
  }

  private async doSearch(kw: string) {
    if (!kw.trim()) {
      return
    }
    this.keyword = kw
    this.inputText = kw
    this.addHistory(kw)
    this.isLoading = true
    try {
      const data = await MUSIC_free_list_API(kw)
      this.results = data.songs ?? []
    } catch (e) {
      console.error('search error:', JSON.stringify(e))
      this.results = []
    } finally {
      this.isLoading = false
    }
  }

  build() {
    Column() {
      // 顶部搜索栏
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([$r('app.color.text_primary')])
          .onClick(() => {
            HMRouterMgr.pop()
          })
        Row() {
          Text('🔍')
            .fontSize(16)
            .margin({ right: 8 })
          TextInput({ placeholder: '搜索歌曲、歌手', text: this.inputText })
            .layoutWeight(1)
            .backgroundColor(Color.Transparent)
            .fontSize(15)
            .onSubmit(() => {
              this.doSearch(this.inputText)
            })
            .onChange((value: string) => {
              this.inputText = value
            })
          if (this.inputText) {
            Text('✕')
              .fontSize(16)
              .fontColor($r('app.color.text_tertiary'))
              .onClick(() => {
                this.inputText = ''
                this.results = []
                this.keyword = ''
              })
          }
        }
        .layoutWeight(1)
        .height(36)
        .borderRadius(18)
        .backgroundColor($r('app.color.card_bg'))
        .margin({ left: 12, right: 12 })

        Text('搜索')
          .fontSize(15)
          .fontColor($r('app.color.accent'))
          .onClick(() => {
            this.doSearch(this.inputText)
          })
      }
      .width('100%')
      .height(56)

      // 内容区
      if (this.keyword === '') {
        // 搜索历史
        Column() {
          if (this.history.length > 0) {
            Row() {
              Text('最近搜索')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
              Text('清空')
                .fontSize(13)
                .fontColor($r('app.color.text_tertiary'))
                .onClick(() => {
                  this.clearHistory()
                })
            }
            .width('100%')
            .margin({ bottom: 12 })

            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(this.history, (item: string) => {
                Row() {
                  Text(item)
                    .fontSize(13)
                    .fontColor($r('app.color.text_body'))
                    .onClick(() => {
                      this.doSearch(item)
                    })
                  Text('✕')
                    .fontSize(12)
                    .fontColor($r('app.color.text_tertiary'))
                    .margin({ left: 6 })
                    .onClick(() => {
                      this.removeHistory(item)
                    })
                }
                .padding({ left: 12, right: 10, top: 6, bottom: 6 })
                .borderRadius(14)
                .backgroundColor($r('app.color.card_bg'))
                .margin({ right: 8, bottom: 8 })
              }, (item: string) => item)
            }
            .width('100%')
          } else {
            Column() {
              Text('🔍')
                .fontSize(48)
              Text('搜索你喜欢的音乐')
                .fontSize(14)
                .fontColor($r('app.color.text_tertiary'))
                .margin({ top: 12 })
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          }
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        // 搜索结果
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(36)
              .height(36)
              .color($r('app.color.accent'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.results.length === 0) {
          Column() {
            Text('没有找到相关歌曲')
              .fontSize(14)
              .fontColor($r('app.color.text_tertiary'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 2 }) {
            ForEach(this.results, (song: SongItem) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(song.name)
                      .fontSize(15)
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(song.artists)
                      .fontSize(12)
                      .fontColor($r('app.color.text_tertiary'))
                      .margin({ top: 3 })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
                    .fontSize(22)
                    .fontColor([$r('app.color.accent')])
                }
                .width('100%')
                .padding({ left: 4, right: 4, top: 12, bottom: 12 })
              }
              .onClick(() => {
                playerManager.play(this.results, this.results.indexOf(song))
              })
            }, (song: SongItem) => `${song.index}_${song.name}`)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
