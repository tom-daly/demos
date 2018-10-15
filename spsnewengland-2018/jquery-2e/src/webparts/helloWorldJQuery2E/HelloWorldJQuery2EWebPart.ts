import * as React from 'react';
import * as ReactDom from 'react-dom';
import { Version } from '@microsoft/sp-core-library';
import {
  BaseClientSideWebPart,
  IPropertyPaneConfiguration,
  PropertyPaneTextField
} from '@microsoft/sp-webpart-base';

import * as strings from 'HelloWorldJQuery2EWebPartStrings';
import HelloWorldJQuery2E from './components/HelloWorldJQuery2E';
import { IHelloWorldJQuery2EProps } from './components/IHelloWorldJQuery2EProps';

export interface IHelloWorldJQuery2EWebPartProps {
  description: string;
}

export default class HelloWorldJQuery2EWebPart extends BaseClientSideWebPart<IHelloWorldJQuery2EWebPartProps> {

  public render(): void {
    const element: React.ReactElement<IHelloWorldJQuery2EProps > = React.createElement(
      HelloWorldJQuery2E,
      {
        description: this.properties.description
      }
    );

    ReactDom.render(element, this.domElement);
  }

  protected onDispose(): void {
    ReactDom.unmountComponentAtNode(this.domElement);
  }

  protected get dataVersion(): Version {
    return Version.parse('1.0');
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
                PropertyPaneTextField('description', {
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
