import * as React from 'react';
import styles from './HelloWorld.module.scss';
import { IHelloWorldProps } from './IHelloWorldProps';
import IHelloWorldState from "./IHelloWorldState";
import { escape } from '@microsoft/sp-lodash-subset';
import { sp, Items } from "@pnp/sp";
import { PrimaryButton } from 'office-ui-fabric-react';
import { TextField } from 'office-ui-fabric-react/lib/TextField';

export default class HelloWorld extends React.Component<IHelloWorldProps, IHelloWorldState> {

  constructor(props: IHelloWorldProps) {
    super(props);

    this.state = {
      items: [],
      textFieldValue: ""
    };
  }

  public componentWillMount(): void {
    this._getListItemsPnP();
  }

  private _getListItemsPnP = (): Promise<any> => {
    return sp.web.lists.getByTitle("Test").items.orderBy("ID", false).top(1).get().then((items: any[]) => {
        this.setState({
          items: items.map(r => r.Title)
        });
    });
  }

  private _addNewListItemPnP(text: string): Promise<any> {
    let newItem: any = {
      Title: text
    };
    return sp.web.lists.getByTitle("Test").items.add(newItem);
  }

  private _onChange = (event: any, newText: string): void => {
    this.setState({
      textFieldValue: newText
    });
  }

  private _onClick = (): void => {
    this._addNewListItemPnP(this.state.textFieldValue).then(this._getListItemsPnP);
  }

  public render(): React.ReactElement<IHelloWorldProps> {
    return (
      <div className={ styles.helloWorld }>
        <div className={ styles.container }>
          <div className={ styles.row }>
            <div className={ styles.column }>
              <span className={ styles.title }>Welcome to SharePoint!</span>
              {
                this.state.items.map(item => {
                  return (
                    <p className={styles.row}>
                      <b>Last Item: </b><span className={styles.subTitle}>
                        {item}
                      </span>
                    </p>
                  );
                })
              }
              <TextField multiline rows={3} value={this.state.textFieldValue} onChange={this._onChange}/><br/>
              <div>
                <PrimaryButton text="Submit" onClick={this._onClick} />
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }
}
