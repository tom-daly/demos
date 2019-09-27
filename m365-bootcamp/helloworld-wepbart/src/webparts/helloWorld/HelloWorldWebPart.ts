import { Version } from "@microsoft/sp-core-library";
import { BaseClientSideWebPart } from "@microsoft/sp-webpart-base";
import { IPropertyPaneConfiguration, PropertyPaneTextField } from "@microsoft/sp-property-pane";
import { escape } from "@microsoft/sp-lodash-subset";
import { SPHttpClient, SPHttpClientResponse } from "@microsoft/sp-http";
import styles from "./HelloWorldWebPart.module.scss";
import * as strings from "HelloWorldWebPartStrings";
import { setup as pnpSetup } from "@pnp/common";
import { sp } from "@pnp/sp";

export interface IHelloWorldWebPartProps {
  description: string;
}

export default class HelloWorldWebPart extends BaseClientSideWebPart<IHelloWorldWebPartProps> {

  public onInit(): Promise<void> {
    return super.onInit().then(_ => {
      pnpSetup({
        spfxContext: this.context
      });
    });
  }

  public render(): void {
    this.domElement.innerHTML = `
      <div class="${styles.helloWorld}">
        <div class="${styles.container}">
          <div class="${styles.row}">
            <div class="${styles.column}">
              <span class="${styles.title}">My List Items</span>
              <div id="myContainer" />
            </div>
          </div>
        </div>
      </div>
      `;

    this._getListItemsPnP().then(response => {
      let items: string[] = [];
      response.map(item => {
        items.push(item.Title);
      });
      this._renderListItems(items);
    });
  }

  private _getListItems(): Promise<any> {
    return this.context.spHttpClient
      .get(
        this.context.pageContext.web.absoluteUrl +
        `/_api/web/lists/GetByTitle('Test')/items`,
        SPHttpClient.configurations.v1
      )
      .then((response: any) => {
        return response.json().then(jsonResponse => {
          return jsonResponse.value;
        });
      });
  }

  private _getListItemsPnP(): Promise<any> {
    return sp.web.lists.getByTitle("Test").items.get().then((items: any[]) => {
        return items;
    });
  }

  private _renderListItems(items: string[]): void {
    let html: string = "";

    items.forEach((item: string) => {
      html += `
    <p class="${styles.row}">
        <span class="${styles.subTitle}">${item}</span>
    </p>`;
    });

    const listItemContainer: Element = this.domElement.querySelector("#myContainer");
    listItemContainer.innerHTML = html;
  }

  protected get dataVersion(): Version {
    return Version.parse("1.0");
  }

  protected getPropertyPaneConfiguration(): IPropertyPaneConfiguration {
    return {
      pages: [
        {
          header: {
            description: strings.PropertyPaneDescription
          },
          groups: [
            {
              groupName: strings.BasicGroupName,
              groupFields: [
                PropertyPaneTextField("description", {
                  label: strings.DescriptionFieldLabel
                })
              ]
            }
          ]
        }
      ]
    };
  }
}
