import IGlobalNavItem from "../model/IGlobalNavItem";
import ISPGlobalNavItem from "../model/ISPGlobalNavItem";
import pnp from "sp-pnp-js";

export default class GlobalNavProvider {
  constructor() {
    pnp.setup({
      // this one is set to hit the root url
      sp: {
        baseUrl: "https://bandrdev.sharepoint.com/sites/GlobalNav"
      }
    });
  }

  public getGlobalNavigation(): Promise<IGlobalNavItem[]> {
    return (
      pnp.sp.web.lists
        .getByTitle("Global Nav List")
        .items.select(
          "Title",
          "GlobalNavUrl",
          "GlobalNavOpenInNewWindow",
          "GlobalNavParent/Title"
        )
        .expand("GlobalNavParent")
        .orderBy("GlobalNavOrder")
        .get()
        .then(
          (items: ISPGlobalNavItem[]): IGlobalNavItem[] => {
            let globalNavItems: IGlobalNavItem[] = [];
            items.forEach(
              (item: ISPGlobalNavItem): void => {
                if (!item.GlobalNavParent) {
                  globalNavItems.push({
                    title: item.Title,
                    url: item.GlobalNavUrl,
                    openInNewWindow: item.GlobalNavOpenInNewWindow,
                    subNavItems: this._getSubNavItems(items, item.Title)
                  });
                }
              }
            );
            return globalNavItems;
          }
        )
    );
  }

  private _getSubNavItems(
    spNavItems: ISPGlobalNavItem[],
    filter: string
  ): IGlobalNavItem[] {
    let subNavItems: IGlobalNavItem[] = [];
    spNavItems.forEach(
      (item: ISPGlobalNavItem): void => {
        if (item.GlobalNavParent && item.GlobalNavParent.Title === filter) {
          subNavItems.push({
            title: item.Title,
            url: item.GlobalNavUrl,
            openInNewWindow: item.GlobalNavOpenInNewWindow
          });
        }
      }
    );
    return subNavItems.length > 0 ? subNavItems : null;
  }
}
